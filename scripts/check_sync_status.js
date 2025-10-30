// Check Sync Status - Verify if reset worked
// Run this in browser console to see actual sync status

(async function checkSyncStatus() {
  console.log('[CHECK] Starting sync status check...\n');

  const DB_NAME = 'Heyho_EventsDB';

  try {
    const db = await new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME);
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });

    console.log('[DB] Opened:', db.name, 'v' + db.version);

    // Check pageVisits
    console.log('\n[PAGE VISITS]');
    const pvTx = db.transaction('pageVisits', 'readonly');
    const pvStore = pvTx.objectStore('pageVisits');

    const allVisits = await new Promise((resolve, reject) => {
      const req = pvStore.getAll();
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });

    const syncedTrue = allVisits.filter(v => v.synced === true).length;
    const syncedFalse = allVisits.filter(v => v.synced === false).length;
    const noSyncedField = allVisits.filter(v => v.synced === undefined).length;

    console.log('Total pageVisits:', allVisits.length);
    console.log('  synced=true:', syncedTrue);
    console.log('  synced=false:', syncedFalse);
    console.log('  synced=undefined:', noSyncedField);

    if (syncedFalse > 0) {
      console.log('\n  Sample unsynced visit:');
      const sample = allVisits.find(v => v.synced === false);
      console.log('    visitId:', sample.visitId);
      console.log('    url:', sample.url);
      console.log('    startedAt:', new Date(sample.startedAt).toLocaleString());
      console.log('    synced:', sample.synced);
    }

    // Check tabAggregates
    console.log('\n[TAB AGGREGATES]');
    const taTx = db.transaction('tabAggregates', 'readonly');
    const taStore = taTx.objectStore('tabAggregates');

    const allAggregates = await new Promise((resolve, reject) => {
      const req = taStore.getAll();
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });

    const aggSyncedTrue = allAggregates.filter(a => a.synced === true).length;
    const aggSyncedFalse = allAggregates.filter(a => a.synced === false).length;
    const aggNoSynced = allAggregates.filter(a => a.synced === undefined).length;

    console.log('Total tabAggregates:', allAggregates.length);
    console.log('  synced=true:', aggSyncedTrue);
    console.log('  synced=false:', aggSyncedFalse);
    console.log('  synced=undefined:', aggNoSynced);

    if (aggSyncedFalse > 0) {
      console.log('\n  Sample unsynced aggregate:');
      const sample = allAggregates.find(a => a.synced === false);
      console.log('    tabId:', sample.tabId);
      console.log('    startTime:', new Date(sample.startTime).toLocaleString());
      console.log('    synced:', sample.synced);
    }

    // Check syncedPageVisits
    console.log('\n[SYNCED PAGE VISITS STORE]');
    const spvTx = db.transaction('syncedPageVisits', 'readonly');
    const spvStore = spvTx.objectStore('syncedPageVisits');

    const syncedVisitsCount = await new Promise((resolve, reject) => {
      const req = spvStore.count();
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });

    console.log('Total records in syncedPageVisits:', syncedVisitsCount);

    db.close();

    console.log('\n' + '='.repeat(60));
    console.log('[SUMMARY]');
    console.log('='.repeat(60));

    if (syncedFalse > 0 || aggSyncedFalse > 0) {
      console.log('[OK] Found unsynced records:');
      console.log('  pageVisits with synced=false:', syncedFalse);
      console.log('  tabAggregates with synced=false:', aggSyncedFalse);
      console.log('\nThese records SHOULD sync on next sync attempt.');
    } else if (noSyncedField > 0 || aggNoSynced > 0) {
      console.log('[WARN] Records missing synced field:');
      console.log('  pageVisits without synced field:', noSyncedField);
      console.log('  tabAggregates without synced field:', aggNoSynced);
      console.log('\nThese records might not sync. Run reset script again.');
    } else {
      console.log('[INFO] All records are marked as synced=true');
      console.log('This is why only new data is syncing.');
      console.log('\nTo sync this data, run the reset_sync_simple.js script.');
    }

  } catch (error) {
    console.error('[ERROR]:', error);
  }
})();
