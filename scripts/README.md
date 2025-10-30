# Browser Extension Scripts

This directory contains utility scripts for managing browser extension data and sync operations.

## Reset IndexedDB Sync Status

**File:** `reset_indexeddb_sync_status.js`

### Purpose

Resets the `synced: true` flag on all records in the browser extension's IndexedDB storage without deleting any data. This forces the extension to re-sync all existing data to the backend server.

### Use Cases

- **Populate demo account data**: Reset sync status to re-sync all browsing data to the `demo@syrupy.com` account
- **Re-sync after backend changes**: Force re-upload of data after database schema changes or backend fixes
- **Testing sync functionality**: Verify that the sync mechanism works correctly with existing data
- **Recover from sync errors**: Reset partial syncs and start fresh

### How It Works

The script:
1. Automatically detects your browser extension's IndexedDB database
2. Finds the relevant object stores: `pageVisits`, `syncedPageVisits`, `tabAggregates`
3. Sets `synced: false` on every record
4. Removes `syncedAt` timestamps if present
5. Preserves all other data (URLs, titles, durations, etc.)
6. Reports progress and summary

### Usage

#### Step 1: Open Browser Console

1. Open the browser where your extension is installed (Chrome, Edge, Brave, etc.)
2. Open Developer Tools:
   - **Mac:** `Cmd + Option + I`
   - **Windows/Linux:** `F12` or `Ctrl + Shift + I`
3. Navigate to the **Console** tab

#### Step 2: Run the Script

**Option A: Copy and paste the entire script**
```javascript
// Copy the entire contents of reset_indexeddb_sync_status.js
// Paste into the console
// Press Enter
```

**Option B: Load from file (if you have access)**
```javascript
// If you can access the file system from the console
const script = await fetch('file:///path/to/reset_indexeddb_sync_status.js');
eval(await script.text());
```

#### Step 3: Verify Results

The script will output:
```
🔄 Starting IndexedDB Sync Status Reset...

📊 Available IndexedDB databases: ['heyho-extension-db']
✅ Detected database: heyho-extension-db

📂 Opened database: heyho-extension-db (version 3)
📋 Available stores: pageVisits, syncedPageVisits, tabAggregates

🎯 Will reset sync status in: pageVisits, syncedPageVisits, tabAggregates

🔧 Processing store: pageVisits
   Found 247 records
   ✅ Updated: 247 records

🔧 Processing store: syncedPageVisits
   Found 189 records
   ✅ Updated: 189 records

🔧 Processing store: tabAggregates
   Found 156 records
   ✅ Updated: 156 records

============================================================
📊 SUMMARY
============================================================

pageVisits:
  Total records: 247
  Updated: 247
  Skipped: 0

syncedPageVisits:
  Total records: 189
  Updated: 189
  Skipped: 0

tabAggregates:
  Total records: 156
  Updated: 156
  Skipped: 0

------------------------------------------------------------
TOTALS:
  Total records: 592
  Total updated: 592
  Total skipped: 0

============================================================
✅ SUCCESS! All records have been marked as unsynced.
💡 Your browser extension will now re-sync all data on the next sync cycle.
```

#### Step 4: Trigger Sync

After running the script, trigger a sync in your browser extension:
- Click the extension icon
- Look for a "Sync Now" button or similar
- Or wait for the automatic sync cycle (usually every few minutes)

### Configuration

If the script can't auto-detect your database, you can manually configure it:

```javascript
// Edit these values at the top of the script
const DB_NAME = 'your-database-name'; // Change this
const STORES_TO_RESET = ['pageVisits', 'syncedPageVisits', 'tabAggregates'];
```

To find your database name:
```javascript
// Run this in the console first
indexedDB.databases().then(dbs => console.log(dbs));
```

### Troubleshooting

#### Error: "None of the expected stores found"

**Cause:** Database name or store names don't match

**Solution:**
1. Run `indexedDB.databases()` to see available databases
2. Open the correct database and check store names
3. Update `DB_NAME` and `STORES_TO_RESET` in the script

#### Error: "Database not found"

**Cause:** Extension hasn't created IndexedDB yet or wrong browser

**Solution:**
1. Make sure you're in the browser where the extension is installed
2. Use the extension to generate some browsing data first
3. Verify extension is active and working

#### No records updated (skipped: X)

**Cause:** Records don't have a `synced` property

**Solution:** This is normal if your extension uses a different field name. Check your extension's code for the sync flag field name.

### Safety

This script is **safe** and **non-destructive**:
- ✅ No data is deleted
- ✅ Only modifies the `synced` flag
- ✅ All browsing history, timestamps, and metadata preserved
- ✅ Read-only detection of databases
- ✅ Comprehensive error handling

### Example Workflow: Populate Demo Account

```bash
# 1. Run the reset script in browser console (see above)

# 2. Trigger extension sync (wait for completion)

# 3. Verify data synced to backend
docker exec heyho-db psql -U postgres -d heyho_sync_development -c "
  SELECT COUNT(*) as page_visits_count
  FROM page_visits
  WHERE user_id = (SELECT id FROM users WHERE email = 'demo@syrupy.com');
"

# 4. Create backup with demo data
docker exec heyho-db pg_dump -U postgres -d heyho_sync_development \
  > backups/heyho_sync_with_demo_data_$(date +%Y%m%d_%H%M%S).sql

# 5. Verify backup contents
grep "^COPY public.page_visits" backups/heyho_sync_with_demo_data_*.sql
```

### Related Files

- **Backup scripts:** See `CLAUDE.md` for backup/restore commands
- **Database setup:** See `docker-compose.yml` for database configuration
- **Extension sync logic:** Check your browser extension repository

---

For more information about the project structure and database management, see the main `CLAUDE.md` file in the project root.
