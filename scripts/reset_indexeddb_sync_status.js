/**
 * IndexedDB Sync Status Reset Script
 *
 * This script resets the 'synced' flag for all records in the browser extension's
 * IndexedDB storage WITHOUT deleting any data. This allows the extension to
 * re-sync all existing data to the backend.
 *
 * USAGE:
 * 1. Open your browser where the extension is installed
 * 2. Open Developer Tools (F12 or Cmd+Option+I)
 * 3. Go to the Console tab
 * 4. Copy and paste this entire script
 * 5. Press Enter to run
 *
 * The script will:
 * - Reset synced status in: pageVisits, tabAggregates (sets synced = false)
 * - Clear tracking store: syncedPageVisits (removes all tracking records)
 * - Preserve actual browsing data (URLs, titles, timestamps, etc.)
 * - Show progress and summary
 */

(async function resetSyncStatus() {
  console.log('🔄 Starting IndexedDB Sync Status Reset...\n');

  // Configuration - adjust these if your database/store names are different
  const DB_NAME = 'Heyho_EventsDB'; // Detected from your extension
  const STORES_TO_RESET = ['pageVisits', 'tabAggregates']; // Stores with 'synced' property to reset
  const STORES_TO_CLEAR = ['syncedPageVisits']; // Tracking stores to completely clear

  const results = {
    success: true,
    stores: {},
    cleared: {},
    errors: []
  };

  try {
    // Try to detect the correct database name
    const databases = await indexedDB.databases();
    console.log('📊 Available IndexedDB databases:', databases.map(db => db.name));

    let dbName = DB_NAME;
    let foundCorrectDb = false;

    // Try to find a database that looks like the extension's database AND has the stores we need
    const possibleNames = databases.filter(db =>
      db.name && (
        db.name.toLowerCase().includes('heyho') ||
        db.name.toLowerCase().includes('syrupy') ||
        db.name.toLowerCase().includes('extension') ||
        db.name.toLowerCase().includes('sync') ||
        db.name.toLowerCase().includes('events')
      )
    );

    // Smart detection: try each possible database and check if it has our stores
    for (const dbInfo of possibleNames) {
      try {
        const testDb = await new Promise((resolve, reject) => {
          const request = indexedDB.open(dbInfo.name);
          request.onsuccess = () => resolve(request.result);
          request.onerror = () => reject(request.error);
          request.onupgradeneeded = () => {
            request.transaction.abort();
            reject(new Error('Upgrade needed'));
          };
        });

        const hasStores = STORES_TO_RESET.some(store =>
          testDb.objectStoreNames.contains(store)
        ) || STORES_TO_CLEAR.some(store =>
          testDb.objectStoreNames.contains(store)
        );

        testDb.close();

        if (hasStores) {
          dbName = dbInfo.name;
          foundCorrectDb = true;
          console.log(`✅ Detected database: ${dbName} (contains expected stores)\n`);
          break;
        }
      } catch (err) {
        // Skip this database
        continue;
      }
    }

    if (!foundCorrectDb) {
      if (possibleNames.length > 0) {
        dbName = possibleNames[0].name;
        console.log(`⚠️  Using first matching database: ${dbName}\n`);
      } else if (databases.length === 1) {
        dbName = databases[0].name;
        console.log(`ℹ️  Using only available database: ${dbName}\n`);
      } else {
        console.log(`⚠️  Could not auto-detect database. Using default: ${dbName}\n`);
        console.log('   If this fails, manually set DB_NAME in the script.\n');
      }
    }

    // Open the database
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open(dbName);

      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      request.onupgradeneeded = () => {
        reject(new Error('Database upgrade needed - this might not be the right database'));
      };
    });

    console.log(`📂 Opened database: ${db.name} (version ${db.version})`);
    console.log(`📋 Available stores: ${Array.from(db.objectStoreNames).join(', ')}\n`);

    // Check which stores exist
    const availableStores = STORES_TO_RESET.filter(store =>
      db.objectStoreNames.contains(store)
    );

    const availableStoresToClear = STORES_TO_CLEAR.filter(store =>
      db.objectStoreNames.contains(store)
    );

    if (availableStores.length === 0 && availableStoresToClear.length === 0) {
      throw new Error(`None of the expected stores found: ${STORES_TO_RESET.join(', ')}, ${STORES_TO_CLEAR.join(', ')}`);
    }

    if (availableStores.length > 0) {
      console.log(`🎯 Will reset sync status in: ${availableStores.join(', ')}`);
    }
    if (availableStoresToClear.length > 0) {
      console.log(`🗑️  Will clear tracking stores: ${availableStoresToClear.join(', ')}`);
    }
    console.log('');

    // Process each store
    for (const storeName of availableStores) {
      console.log(`\n🔧 Processing store: ${storeName}`);

      try {
        const transaction = db.transaction(storeName, 'readwrite');
        const store = transaction.objectStore(storeName);

        // Get all records
        const getAllRequest = store.getAll();
        const records = await new Promise((resolve, reject) => {
          getAllRequest.onsuccess = () => resolve(getAllRequest.result);
          getAllRequest.onerror = () => reject(getAllRequest.error);
        });

        console.log(`   Found ${records.length} records`);

        if (records.length === 0) {
          results.stores[storeName] = { count: 0, updated: 0, skipped: 0 };
          console.log(`   ⚠️  Store is empty, skipping`);
          continue;
        }

        let updated = 0;
        let skipped = 0;

        // Update each record
        for (const record of records) {
          // Check if record has synced property
          if ('synced' in record) {
            // Reset synced to false
            record.synced = false;

            // If there's a syncedAt timestamp, remove it
            if ('syncedAt' in record) {
              delete record.syncedAt;
            }

            const putRequest = store.put(record);
            await new Promise((resolve, reject) => {
              putRequest.onsuccess = () => resolve();
              putRequest.onerror = () => reject(putRequest.error);
            });

            updated++;
          } else {
            skipped++;
          }
        }

        // Wait for transaction to complete
        await new Promise((resolve, reject) => {
          transaction.oncomplete = () => resolve();
          transaction.onerror = () => reject(transaction.error);
        });

        results.stores[storeName] = {
          count: records.length,
          updated: updated,
          skipped: skipped
        };

        console.log(`   ✅ Updated: ${updated} records`);
        if (skipped > 0) {
          console.log(`   ℹ️  Skipped: ${skipped} records (no synced property)`);
        }

      } catch (error) {
        console.error(`   ❌ Error processing ${storeName}:`, error);
        results.errors.push({ store: storeName, error: error.message });
        results.success = false;
      }
    }

    // Clear tracking stores completely
    for (const storeName of availableStoresToClear) {
      console.log(`\n🗑️  Clearing store: ${storeName}`);

      try {
        const transaction = db.transaction(storeName, 'readwrite');
        const store = transaction.objectStore(storeName);

        // Count records before clearing
        const countRequest = store.count();
        const count = await new Promise((resolve, reject) => {
          countRequest.onsuccess = () => resolve(countRequest.result);
          countRequest.onerror = () => reject(countRequest.error);
        });

        console.log(`   Found ${count} records to clear`);

        if (count === 0) {
          results.cleared[storeName] = { count: 0, cleared: 0 };
          console.log(`   ⚠️  Store is already empty, skipping`);
          continue;
        }

        // Clear all records
        const clearRequest = store.clear();
        await new Promise((resolve, reject) => {
          clearRequest.onsuccess = () => resolve();
          clearRequest.onerror = () => reject(clearRequest.error);
        });

        // Wait for transaction to complete
        await new Promise((resolve, reject) => {
          transaction.oncomplete = () => resolve();
          transaction.onerror = () => reject(transaction.error);
        });

        results.cleared[storeName] = {
          count: count,
          cleared: count
        };

        console.log(`   ✅ Cleared: ${count} records`);

      } catch (error) {
        console.error(`   ❌ Error clearing ${storeName}:`, error);
        results.errors.push({ store: storeName, error: error.message });
        results.success = false;
      }
    }

    db.close();

    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('📊 SUMMARY');
    console.log('='.repeat(60));

    let totalRecords = 0;
    let totalUpdated = 0;
    let totalSkipped = 0;
    let totalCleared = 0;

    if (Object.keys(results.stores).length > 0) {
      console.log('\n📝 Reset Stores:');
      for (const [storeName, stats] of Object.entries(results.stores)) {
        console.log(`\n${storeName}:`);
        console.log(`  Total records: ${stats.count}`);
        console.log(`  Updated: ${stats.updated}`);
        console.log(`  Skipped: ${stats.skipped}`);

        totalRecords += stats.count;
        totalUpdated += stats.updated;
        totalSkipped += stats.skipped;
      }
    }

    if (Object.keys(results.cleared).length > 0) {
      console.log('\n🗑️  Cleared Stores:');
      for (const [storeName, stats] of Object.entries(results.cleared)) {
        console.log(`\n${storeName}:`);
        console.log(`  Records cleared: ${stats.cleared}`);
        totalCleared += stats.cleared;
      }
    }

    console.log('\n' + '-'.repeat(60));
    console.log(`TOTALS:`);
    console.log(`  Records reset: ${totalUpdated}`);
    console.log(`  Records cleared: ${totalCleared}`);
    console.log(`  Total affected: ${totalUpdated + totalCleared}`);

    if (results.errors.length > 0) {
      console.log('\n⚠️  ERRORS:');
      results.errors.forEach(err => {
        console.log(`  ${err.store}: ${err.error}`);
      });
    }

    console.log('\n' + '='.repeat(60));

    if (results.success && (totalUpdated > 0 || totalCleared > 0)) {
      console.log('✅ SUCCESS!');
      if (totalUpdated > 0) {
        console.log(`   - ${totalUpdated} records marked as unsynced`);
      }
      if (totalCleared > 0) {
        console.log(`   - ${totalCleared} tracking records cleared`);
      }
      console.log('\n💡 Your browser extension will now re-sync all data on the next sync cycle.');
    } else if (totalUpdated === 0 && totalCleared === 0) {
      console.log('ℹ️  No records were updated or cleared. They may already be unsynced or have no data.');
    } else {
      console.log('⚠️  Completed with some errors. Check the error messages above.');
    }

    return results;

  } catch (error) {
    console.error('\n❌ FATAL ERROR:', error);
    console.error('\n💡 Troubleshooting tips:');
    console.error('   1. Make sure you\'re running this in the same browser where the extension is installed');
    console.error('   2. Check if the database name is correct (see list above)');
    console.error('   3. Verify the extension has created IndexedDB data');
    console.error('   4. Try running indexedDB.databases() to see all databases');

    return { success: false, error: error.message };
  }
})();
