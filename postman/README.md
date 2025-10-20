# HeyHo Sync API - Postman Collection

Comprehensive Postman collection for testing the HeyHo Sync API with both success and failure scenarios.

## 📦 Contents

- `HeyHo_Sync_API.postman_collection.json` - Main collection with all API endpoints
- `HeyHo_Sync_API.postman_environment.json` - Environment variables for local development
- `README.md` - This file

## 🚀 Quick Start

### 1. Import Files into Postman

**Important**: Use Postman Desktop App (v10.0+) for best compatibility.

1. Open Postman Desktop App
2. Click **Import** button (top left)
3. Select **files** tab
4. Click **Upload Files** and select both:
   - `HeyHo_Sync_API.postman_collection.json`
   - `HeyHo_Sync_API.postman_environment.json`
5. Click **Import**
6. Verify both items appear in your Collections and Environments

**If import fails**:
- Ensure you're using Postman Desktop App (not web version)
- Try importing one file at a time
- Check Postman version is v10.0 or higher
- Verify JSON files are not corrupted (open in text editor to check)

### 2. Select Environment

1. In the top-right corner, select **HeyHo Sync API - Local Development** from the environment dropdown
2. Verify `base_url` is set correctly (default: `http://localhost:3001`)

### 3. Start Your Local API Server

```bash
# From platform root
docker-compose up heyho-sync-be

# OR from apps/heyho-sync-be
docker-compose up
```

### 4. Run Initial Setup

**IMPORTANT**: Before testing Insights API, you must authenticate!

**Option A: Use Demo User (Recommended)**
1. Go to **5. Insights API** → **Setup: Login for Insights Tests**
2. Click **Send**
3. ✅ Auth token is automatically stored

**Option B: Create New Test User**
1. Go to **1. Authentication** → **1.1 Create Account - Success**
2. Click **Send** (generates unique test user)
3. Then run **1.3 Login - Success**

### 5. Test Insights API

Now you can run any request in the **5. Insights API** folder!

## 📚 Collection Structure

### 0. Health Check
- **API Health Check** - Verify API is running

### 1. Authentication (5 requests)
- ✅ Create Account - Success
- ❌ Create Account - Missing Email
- ✅ Login - Success
- ❌ Login - Invalid Credentials
- ✅ Logout - Success

### 5. Insights API (25+ requests)

#### Daily Summary (4 scenarios)
- ✅ Success with default parameters
- ✅ Success with specific date
- ❌ Unauthorized (no token)
- ⚠️  Invalid date format (edge case)

#### Weekly Summary (4 scenarios)
- ✅ Success for current week
- ✅ Success with ISO week format (2025-W42)
- ⚠️  Invalid week format (graceful fallback)
- ❌ Unauthorized

#### Top Sites (6 scenarios)
- ✅ Success with defaults
- ✅ With period parameter (month)
- ✅ Sort by visits
- ✅ With custom limit
- ⚠️  Limit too high (clamped to 50)
- ❌ Unauthorized

#### Recent Activity (5 scenarios)
- ✅ Success with defaults
- ✅ With custom limit
- ✅ With since timestamp
- ⚠️  Limit too high (clamped to 100)
- ❌ Unauthorized

#### Productivity Hours (4 scenarios)
- ✅ Success with defaults
- ✅ Week period
- ✅ Month period
- ❌ Unauthorized

## 🧪 Test Coverage

Each request includes automated tests that verify:

### Success Scenarios (✅)
- Status code is 200
- Response structure is correct
- All required fields are present
- Data types are correct
- Arrays have expected items
- Numeric values are within valid ranges

### Failure Scenarios (❌)
- Status code is 401 (unauthorized)
- Status code is 422 (unprocessable entity)
- Error messages are present
- Proper error handling

### Edge Cases (⚠️)
- Parameter validation
- Limit clamping
- Invalid input handling
- Graceful fallbacks

## 🔧 Environment Variables

The collection uses these environment variables:

| Variable | Description | Auto-Set |
|----------|-------------|----------|
| `base_url` | API base URL | Manual |
| `auth_token` | JWT authentication token | ✅ Auto |
| `test_email` | Generated test user email | ✅ Auto |
| `test_password` | Generated test user password | ✅ Auto |
| `demo_email` | Demo user email | Manual |
| `demo_password` | Demo user password | Manual |
| `test_date` | Date for testing | ✅ Auto |
| `since_timestamp` | Timestamp for activity filter | ✅ Auto |

## 📊 Running Tests

### Run Individual Request
1. Select a request
2. Click **Send**
3. View response in **Body** tab
4. View test results in **Test Results** tab (bottom)

### Run Entire Folder
1. Right-click on a folder (e.g., "Daily Summary")
2. Select **Run folder**
3. Click **Run HeyHo Sync API - Comprehensive Test Suite**
4. View results summary

### Run Collection Runner
1. Click **Runner** button (bottom left)
2. Select **HeyHo Sync API - Comprehensive Test Suite**
3. Select **HeyHo Sync API - Local Development** environment
4. Choose which folders to run
5. Click **Run HeyHo Sync API**
6. View detailed test results with pass/fail counts

## 🎯 Testing Workflow

### Recommended Order for First-Time Testing:

1. **Health Check**
   ```
   0. Health Check → API Health Check
   ```

2. **Authentication Setup**
   ```
   5. Insights API → Setup: Login for Insights Tests
   ```

3. **Test All Insights Endpoints**
   ```
   Run entire "5. Insights API" folder
   ```

4. **Test Success Scenarios Only**
   ```
   Run all requests with "Success" in the name
   ```

5. **Test Failure Scenarios**
   ```
   Run all requests with "Unauthorized" or "Invalid" in the name
   ```

## 🐛 Troubleshooting

### Problem: Collection import fails

**Solution**:
- Use Postman Desktop App v10.0+ (not web version)
- Import environment file first, then collection
- Try: File → Import → Upload Files (not drag-and-drop)
- Ensure files are not corrupted: `python3 -m json.tool <filename>`
- Check Postman Console (View → Show Postman Console) for error details

### Problem: "401 Unauthorized" on Insights API

**Solution**: Run "Setup: Login for Insights Tests" first to get auth token

### Problem: "Connection refused" or timeout

**Solution**:
- Verify API server is running: `docker-compose ps`
- Check `base_url` in environment matches your server
- Default should be `http://localhost:3001`
- Try: `curl http://localhost:3001/api/v1/health` to verify server

### Problem: Tests are failing

**Solution**:
- Check **Test Results** tab for specific failures
- Verify response structure matches expectations
- Check API server logs: `docker-compose logs heyho-sync-be`

### Problem: Demo user login fails

**Solution**:
- Run database seed: `docker-compose run --rm heyho-sync-be bundle exec rails db:seed`
- Or create a new test user with "1.1 Create Account - Success"

### Problem: Empty data in responses

**Solution**:
- Insights API needs browsing data to return meaningful results
- Option 1: Use the demo user (has seeded data)
- Option 2: POST data to `/api/v1/data/sync` endpoint first
- Option 3: Test with empty data to verify empty state handling

## 📝 Response Examples

### Daily Summary Success Response
```json
{
  "success": true,
  "data": {
    "date": "2025-10-20",
    "total_sites_visited": 42,
    "unique_domains": 15,
    "total_time_seconds": 3600,
    "active_time_seconds": 2400,
    "avg_engagement_rate": 0.68,
    "top_domain": {
      "domain": "github.com",
      "visits": 12,
      "time_seconds": 1200
    },
    "hourly_breakdown": [
      {
        "hour": 9,
        "visits": 8,
        "avg_engagement": 0.75
      }
    ]
  }
}
```

### Error Response
```json
{
  "error": "Unauthorized: Missing or invalid token"
}
```

## 🔐 Security Notes

- Never commit Postman files with real tokens to git
- The environment file uses demo credentials - change for production
- Auth tokens are stored as "secret" type in environment
- Tokens expire after 1 hour (configurable in API)

## 📖 API Documentation

For detailed API documentation, see:
- [API Routes](../config/routes.rb)
- [Insights API Implementation](../docs/reqts/phase-2/03-insights-apis.md)
- [CLAUDE.md](../CLAUDE.md) - Code style guide

## 🤝 Contributing

To add new test scenarios:

1. Add request to appropriate folder
2. Add pre-request script if needed (setup)
3. Add test script with validations:
   ```javascript
   pm.test("Description", function () {
       pm.response.to.have.status(200);
       const jsonData = pm.response.json();
       pm.expect(jsonData.success).to.be.true;
   });
   ```
4. Export collection and update this README

## 📜 License

Part of the HeyHo Sync Backend project.

## 💡 Tips

- Use **Console** (View → Show Postman Console) to debug scripts
- Use **{{variable}}** syntax to reference environment variables
- Tests run automatically after each request
- Pre-request scripts run before each request
- Collection-level scripts apply to all requests

## 📞 Support

If you encounter issues:
1. Check the Troubleshooting section above
2. Review test results in Console
3. Check API server logs
4. Verify environment variables are set correctly

---

**Happy Testing! 🚀**
