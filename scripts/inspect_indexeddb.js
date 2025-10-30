/**
 * IndexedDB Inspector Script
 *
 * This script inspects all IndexedDB databases and their object stores
 * to help you identify the correct names for the reset script.
 *
 * USAGE:
 * 1. Open your browser where the extension is installed
 * 2. Open Developer Tools (F12 or Cmd+Option+I)
 * 3. Go to the Console tab
 * 4. Copy and paste this entire script
 * 5. Press Enter to run
 */

(async function inspectIndexedDB() {
  console.log('🔍 Inspecting IndexedDB...\n');
  console.log('='.repeat(60));

  try {
    // Get all databases
    const databases = await indexedDB.databases();

    if (databases.length === 0) {
      console.log('❌ No IndexedDB databases found!');
      console.log('\n💡 This could mean:');
      console.log('   - Extension is not installed');
      console.log('   - Extension hasn\'t created any data yet');
      console.log('   - Wrong browser context');
      return;
    }

    console.log(`📊 Found ${databases.length} database(s):\n`);

    // Inspect each database
    for (let i = 0; i < databases.length; i++) {
      const dbInfo = databases[i];
      console.log(`${i + 1}. Database: "${dbInfo.name}" (version ${dbInfo.version || 'unknown'})`);

      try {
        // Open the database to inspect its structure
        const db = await new Promise((resolve, reject) => {
          const request = indexedDB.open(dbInfo.name);

          request.onsuccess = () => resolve(request.result);
          request.onerror = () => reject(request.error);
          request.onupgradeneeded = () => {
            // Cancel the upgrade and close
            request.transaction.abort();
            reject(new Error('Upgrade needed - skipping'));
          };
        });

        const storeNames = Array.from(db.objectStoreNames);
        console.log(`   📋 Object Stores (${storeNames.length}):`);

        if (storeNames.length === 0) {
          console.log('      (empty database)');
        } else {
          for (const storeName of storeNames) {
            // Try to count records in each store
            try {
              const transaction = db.transaction(storeName, 'readonly');
              const store = transaction.objectStore(storeName);
              const countRequest = store.count();

              const count = await new Promise((resolve, reject) => {
                countRequest.onsuccess = () => resolve(countRequest.result);
                countRequest.onerror = () => resolve('?');
              });

              // Check if records have 'synced' property
              if (count > 0) {
                const getAllRequest = store.getAll();
                const records = await new Promise((resolve, reject) => {
                  getAllRequest.onsuccess = () => resolve(getAllRequest.result);
                  getAllRequest.onerror = () => resolve([]);
                });

                const hasSyncedProp = records.length > 0 && 'synced' in records[0];
                const syncedCount = records.filter(r => r.synced === true).length;
                const unsyncedCount = records.filter(r => r.synced === false).length;

                if (hasSyncedProp) {
                  console.log(`      ✅ "${storeName}" - ${count} records (${syncedCount} synced, ${unsyncedCount} unsynced)`);
                } else {
                  console.log(`      📦 "${storeName}" - ${count} records (no 'synced' property)`);
                }
              } else {
                console.log(`      📦 "${storeName}" - ${count} records`);
              }
            } catch (err) {
              console.log(`      📦 "${storeName}" - (couldn't count)`);
            }
          }
        }

        db.close();
        console.log('');

      } catch (err) {
        console.log(`   ⚠️  Could not inspect: ${err.message}\n`);
      }
    }

    console.log('='.repeat(60));
    console.log('\n💡 Next Steps:');
    console.log('   1. Identify which database contains your extension data');
    console.log('   2. Note the object store names that have "synced" property');
    console.log('   3. Update the reset script with these names');
    console.log('\n📝 To update the reset script:');
    console.log('   - Set DB_NAME to the correct database name');
    console.log('   - Set STORES_TO_RESET to the list of stores with synced data');

  } catch (error) {
    console.error('\n❌ Error:', error);
    console.error('\n💡 Try running: await indexedDB.databases()');
  }
})();
