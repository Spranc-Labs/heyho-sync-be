// IndexedDB Sync Reset Script - Clean version without emoji encoding issues
// Copy and paste this entire script into your browser console

(async function resetSyncStatus() {
  console.log('Starting IndexedDB Sync Status Reset...\n');

  const DB_NAME = 'Heyho_EventsDB';
  const STORES_TO_RESET = ['pageVisits', 'tabAggregates'];
  const STORES_TO_CLEAR = ['syncedPageVisits'];

  const results = {
    success: true,
    stores: {},
    cleared: {},
    errors: []
  };

  try {
    const databases = await indexedDB.databases();
    console.log('Available IndexedDB databases:', databases.map(db => db.name));

    let dbName = DB_NAME;
    let foundCorrectDb = false;

    const possibleNames = databases.filter(db =>
      db.name && (
        db.name.toLowerCase().includes('heyho') ||
        db.name.toLowerCase().includes('syrupy') ||
        db.name.toLowerCase().includes('extension') ||
        db.name.toLowerCase().includes('sync') ||
        db.name.toLowerCase().includes('events')
      )
    );

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
          console.log('[OK] Detected database:', dbName, '(contains expected stores)\n');
          break;
        }
      } catch (err) {
        continue;
      }
    }

    if (!foundCorrectDb) {
      if (possibleNames.length > 0) {
        dbName = possibleNames[0].name;
        console.log('[WARN] Using first matching database:', dbName, '\n');
      } else {
        console.log('[WARN] Could not auto-detect database. Using default:', dbName, '\n');
      }
    }

    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open(dbName);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
      request.onupgradeneeded = () => {
        reject(new Error('Database upgrade needed'));
      };
    });

    console.log('[DB] Opened database:', db.name, '(version', db.version + ')');
    console.log('[DB] Available stores:', Array.from(db.objectStoreNames).join(', '), '\n');

    const availableStores = STORES_TO_RESET.filter(store =>
      db.objectStoreNames.contains(store)
    );

    const availableStoresToClear = STORES_TO_CLEAR.filter(store =>
      db.objectStoreNames.contains(store)
    );

    if (availableStores.length === 0 && availableStoresToClear.length === 0) {
      throw new Error('None of the expected stores found: ' + STORES_TO_RESET.join(', ') + ', ' + STORES_TO_CLEAR.join(', '));
    }

    if (availableStores.length > 0) {
      console.log('[PLAN] Will reset sync status in:', availableStores.join(', '));
    }
    if (availableStoresToClear.length > 0) {
      console.log('[PLAN] Will clear tracking stores:', availableStoresToClear.join(', '));
    }
    console.log('');

    // Process stores to reset
    for (const storeName of availableStores) {
      console.log('[PROCESSING]', storeName);

      try {
        const transaction = db.transaction(storeName, 'readwrite');
        const store = transaction.objectStore(storeName);

        const getAllRequest = store.getAll();
        const records = await new Promise((resolve, reject) => {
          getAllRequest.onsuccess = () => resolve(getAllRequest.result);
          getAllRequest.onerror = () => reject(getAllRequest.error);
        });

        console.log('  Found', records.length, 'records');

        if (records.length === 0) {
          results.stores[storeName] = { count: 0, updated: 0, skipped: 0 };
          console.log('  [SKIP] Store is empty');
          continue;
        }

        let updated = 0;
        let skipped = 0;

        for (const record of records) {
          if ('synced' in record) {
            record.synced = false;

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

        await new Promise((resolve, reject) => {
          transaction.oncomplete = () => resolve();
          transaction.onerror = () => reject(transaction.error);
        });

        results.stores[storeName] = {
          count: records.length,
          updated: updated,
          skipped: skipped
        };

        console.log('  [OK] Updated:', updated, 'records');
        if (skipped > 0) {
          console.log('  [INFO] Skipped:', skipped, 'records (no synced property)');
        }

      } catch (error) {
        console.error('  [ERROR] Error processing', storeName + ':', error);
        results.errors.push({ store: storeName, error: error.message });
        results.success = false;
      }
    }

    // Clear tracking stores
    for (const storeName of availableStoresToClear) {
      console.log('[CLEARING]', storeName);

      try {
        const transaction = db.transaction(storeName, 'readwrite');
        const store = transaction.objectStore(storeName);

        const countRequest = store.count();
        const count = await new Promise((resolve, reject) => {
          countRequest.onsuccess = () => resolve(countRequest.result);
          countRequest.onerror = () => reject(countRequest.error);
        });

        console.log('  Found', count, 'records to clear');

        if (count === 0) {
          results.cleared[storeName] = { count: 0, cleared: 0 };
          console.log('  [SKIP] Store is already empty');
          continue;
        }

        const clearRequest = store.clear();
        await new Promise((resolve, reject) => {
          clearRequest.onsuccess = () => resolve();
          clearRequest.onerror = () => reject(clearRequest.error);
        });

        await new Promise((resolve, reject) => {
          transaction.oncomplete = () => resolve();
          transaction.onerror = () => reject(transaction.error);
        });

        results.cleared[storeName] = {
          count: count,
          cleared: count
        };

        console.log('  [OK] Cleared:', count, 'records');

      } catch (error) {
        console.error('  [ERROR] Error clearing', storeName + ':', error);
        results.errors.push({ store: storeName, error: error.message });
        results.success = false;
      }
    }

    db.close();

    // Print summary
    console.log('\n' + '='.repeat(60));
    console.log('SUMMARY');
    console.log('='.repeat(60));

    let totalUpdated = 0;
    let totalCleared = 0;

    if (Object.keys(results.stores).length > 0) {
      console.log('\nReset Stores:');
      for (const [storeName, stats] of Object.entries(results.stores)) {
        console.log('  ' + storeName + ':', stats.updated, 'updated');
        totalUpdated += stats.updated;
      }
    }

    if (Object.keys(results.cleared).length > 0) {
      console.log('\nCleared Stores:');
      for (const [storeName, stats] of Object.entries(results.cleared)) {
        console.log('  ' + storeName + ':', stats.cleared, 'cleared');
        totalCleared += stats.cleared;
      }
    }

    console.log('\n' + '-'.repeat(60));
    console.log('TOTALS:');
    console.log('  Records reset:', totalUpdated);
    console.log('  Records cleared:', totalCleared);
    console.log('  Total affected:', totalUpdated + totalCleared);

    if (results.errors.length > 0) {
      console.log('\n[ERRORS]:');
      results.errors.forEach(err => {
        console.log('  ' + err.store + ':', err.error);
      });
    }

    console.log('\n' + '='.repeat(60));

    if (results.success && (totalUpdated > 0 || totalCleared > 0)) {
      console.log('[SUCCESS]');
      if (totalUpdated > 0) {
        console.log('  -', totalUpdated, 'records marked as unsynced');
      }
      if (totalCleared > 0) {
        console.log('  -', totalCleared, 'tracking records cleared');
      }
      console.log('\nYour browser extension will now re-sync all data on the next sync cycle.');
    } else if (totalUpdated === 0 && totalCleared === 0) {
      console.log('[INFO] No records were updated or cleared.');
    } else {
      console.log('[WARN] Completed with some errors. Check the error messages above.');
    }

    return results;

  } catch (error) {
    console.error('\n[FATAL ERROR]:', error);
    console.error('\nTroubleshooting tips:');
    console.error('  1. Make sure you are running this in the same browser where the extension is installed');
    console.error('  2. Check if the database name is correct (see list above)');
    console.error('  3. Verify the extension has created IndexedDB data');
    console.error('  4. Try running: await indexedDB.databases()');

    return { success: false, error: error.message };
  }
})();
