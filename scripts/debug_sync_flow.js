// Debug Sync Flow - Check what sync function sees
// Run this in browser console BEFORE clicking sync button

(async function debugSyncFlow() {
  console.log('[DEBUG] Checking sync flow...\n');

  try {
    // Step 1: Check if StorageModule exists
    if (!self.StorageModule) {
      console.error('[ERROR] StorageModule not found!');
      return;
    }
    console.log('[OK] StorageModule exists');

    // Step 2: Call getUnsyncedPageVisits directly
    console.log('\n[TEST] Calling getUnsyncedPageVisits()...');
    const unsyncedVisits = await self.StorageModule.getUnsyncedPageVisits();
    console.log('[RESULT] getUnsyncedPageVisits returned:', unsyncedVisits.length, 'records');

    if (unsyncedVisits.length > 0) {
      console.log('\n  Sample unsynced visit:');
      const sample = unsyncedVisits[0];
      console.log('    visitId:', sample.visitId);
      console.log('    url:', sample.url);
      console.log('    domain:', sample.domain);
      console.log('    startedAt:', new Date(sample.startedAt).toLocaleString());
      console.log('    synced:', sample.synced);
      console.log('    category:', sample.category);
    }

    // Step 3: Call getUnsyncedTabAggregates directly
    console.log('\n[TEST] Calling getUnsyncedTabAggregates()...');
    const unsyncedAggregates = await self.StorageModule.getUnsyncedTabAggregates();
    console.log('[RESULT] getUnsyncedTabAggregates returned:', unsyncedAggregates.length, 'records');

    if (unsyncedAggregates.length > 0) {
      console.log('\n  Sample unsynced aggregate:');
      const sample = unsyncedAggregates[0];
      console.log('    tabId:', sample.tabId);
      console.log('    startTime:', new Date(sample.startTime).toLocaleString());
      console.log('    synced:', sample.synced);
    }

    // Step 4: Check INVALID_URL_PREFIXES
    console.log('\n[CHECK] Checking URL filtering...');
    const Constants = self.Constants || {};
    const invalidPrefixes = Constants.INVALID_URL_PREFIXES || [];
    console.log('INVALID_URL_PREFIXES:', invalidPrefixes);

    if (invalidPrefixes.length > 0 && unsyncedVisits.length > 0) {
      const filtered = unsyncedVisits.filter(v => {
        const url = v.url || '';
        return invalidPrefixes.some(prefix => url.startsWith(prefix));
      });
      console.log('URLs that would be filtered:', filtered.length);
      if (filtered.length > 0) {
        console.log('  Sample filtered URL:', filtered[0].url);
      }
    }

    // Step 5: Check authentication
    console.log('\n[CHECK] Checking authentication...');
    if (self.AuthManager && self.AuthManager.isAuthenticated) {
      const isAuth = self.AuthManager.isAuthenticated();
      console.log('isAuthenticated:', isAuth);
    } else {
      console.log('[WARN] AuthManager not available');
    }

    // Step 6: Check sync state
    console.log('\n[CHECK] Checking sync state...');
    if (self.SyncManager && self.SyncManager.getSyncState) {
      const syncState = self.SyncManager.getSyncState();
      console.log('Sync state:', syncState);
    }

    console.log('\n' + '='.repeat(60));
    console.log('[SUMMARY]');
    console.log('='.repeat(60));

    if (unsyncedVisits.length > 0 || unsyncedAggregates.length > 0) {
      console.log('[OK] Extension CAN see unsynced records:');
      console.log('  pageVisits:', unsyncedVisits.length);
      console.log('  tabAggregates:', unsyncedAggregates.length);
      console.log('\n[NEXT] Try triggering a sync and watch for console logs.');
      console.log('Look for messages like:');
      console.log('  - "Starting data sync to backend..."');
      console.log('  - "Syncing X page visits and Y tab aggregates"');
      console.log('  - "No data to sync"');
      console.log('  - "Skipping sync - user not authenticated"');
    } else {
      console.log('[WARN] Extension sees 0 unsynced records');
      console.log('This is unexpected. The reset may not have worked properly.');
    }

  } catch (error) {
    console.error('[ERROR]:', error);
    console.error('Stack:', error.stack);
  }
})();
