# Postman Testing Guide - Phase 3 APIs

This guide covers how to test Pattern Detection, Reading List, and Research Sessions APIs using Postman.

## Prerequisites

1. **Start the development server**:
   ```bash
   docker-compose up
   ```

2. **Run migrations** (if not already done):
   ```bash
   docker-compose run --rm app bundle exec rails db:migrate
   ```

3. **Base URL**: `http://localhost:3000/api/v1`

## 1. Authentication Setup

All Phase 3 endpoints require authentication. First, you need to register and login.

### 1.1 Register a User

**POST** `http://localhost:3000/api/v1/auth/create-account`

**Headers**:
```
Content-Type: application/json
```

**Body** (raw JSON):
```json
{
  "login": "testuser@example.com",
  "password": "SecurePassword123!",
  "password-confirm": "SecurePassword123!"
}
```

**Expected Response** (201 Created):
```json
{
  "success": true,
  "message": "Account created successfully"
}
```

### 1.2 Login

**POST** `http://localhost:3000/api/v1/auth/login`

**Headers**:
```
Content-Type: application/json
```

**Body** (raw JSON):
```json
{
  "login": "testuser@example.com",
  "password": "SecurePassword123!"
}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Logged in successfully",
  "data": {
    "access_token": "eyJhbGc...",
    "refresh_token": "dGVzdC...",
    "expires_in": 900
  }
}
```

**⚠️ IMPORTANT**: Copy the `access_token` from the response. You'll need it for all subsequent requests.

### 1.3 Set Up Authorization in Postman

For all requests below, add this header:

**Headers**:
```
Authorization: Bearer YOUR_ACCESS_TOKEN_HERE
Content-Type: application/json
```

**Tip**: Create a Postman Environment variable:
1. Click "Environments" in Postman
2. Create new environment "HeyHo Dev"
3. Add variable: `access_token` = (paste your token)
4. Use `{{access_token}}` in Authorization header: `Bearer {{access_token}}`

---

## 2. Setup: Create Test Data

Before testing pattern detection, you need some page visits in the database.

### 2.1 Sync Browsing Data

**POST** `http://localhost:3000/api/v1/data/sync`

**Headers**:
```
Authorization: Bearer {{access_token}}
Content-Type: application/json
```

**Body** (raw JSON):
```json
{
  "page_visits": [
    {
      "id": "pv_1",
      "url": "https://reactjs.org/docs/hooks-intro.html",
      "title": "Introducing Hooks - React",
      "domain": "reactjs.org",
      "visited_at": "2025-01-20T14:30:00Z",
      "duration_seconds": 2400,
      "engagement_rate": 0.15,
      "visit_count": 1,
      "metadata": {
        "category": "learning"
      }
    },
    {
      "id": "pv_2",
      "url": "https://stackoverflow.com/questions/react-hooks",
      "title": "React Hooks Questions - Stack Overflow",
      "domain": "stackoverflow.com",
      "visited_at": "2025-01-20T14:35:00Z",
      "duration_seconds": 600,
      "engagement_rate": 0.7,
      "visit_count": 3,
      "metadata": {
        "category": "learning"
      }
    },
    {
      "id": "pv_3",
      "url": "https://medium.com/react-hooks-deep-dive",
      "title": "React Hooks Deep Dive",
      "domain": "medium.com",
      "visited_at": "2025-01-20T14:40:00Z",
      "duration_seconds": 180,
      "engagement_rate": 0.25,
      "visit_count": 4,
      "metadata": {
        "category": "learning"
      }
    },
    {
      "id": "pv_4",
      "url": "https://github.com/facebook/react",
      "title": "React GitHub Repository",
      "domain": "github.com",
      "visited_at": "2025-01-20T14:45:00Z",
      "duration_seconds": 900,
      "engagement_rate": 0.8,
      "visit_count": 1,
      "metadata": {
        "category": "work"
      }
    }
  ]
}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Data synced successfully",
  "data": {
    "page_visits": {
      "created": 4,
      "updated": 0
    }
  }
}
```

---

## 3. Pattern Detection APIs

### 3.1 Detect Hoarder Tabs

Finds tabs open for a long time with minimal engagement.

**GET** `http://localhost:3000/api/v1/pattern_detections/hoarder_tabs`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Query Parameters** (optional):
- `min_open_time` - Minimum time in minutes (default: 30)
- `max_engagement` - Maximum engagement rate (default: 0.2)

**Example with parameters**:
```
http://localhost:3000/api/v1/pattern_detections/hoarder_tabs?min_open_time=20&max_engagement=0.3
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "hoarder_tabs": [
      {
        "page_visit_id": "pv_1",
        "url": "https://reactjs.org/docs/hooks-intro.html",
        "title": "Introducing Hooks - React",
        "domain": "reactjs.org",
        "open_time_seconds": 2400,
        "engagement_rate": 0.15,
        "first_visit_at": "2025-01-20T14:30:00.000Z",
        "last_visit_at": "2025-01-20T14:30:00.000Z",
        "visit_count": 1,
        "suggested_action": "save_to_reading_list"
      }
    ],
    "count": 1,
    "criteria": {
      "min_open_time_minutes": 20,
      "max_engagement_rate": 0.3
    }
  }
}
```

### 3.2 Detect Serial Openers

Finds resources opened repeatedly but never finished.

**GET** `http://localhost:3000/api/v1/pattern_detections/serial_openers`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Query Parameters** (optional):
- `min_visits` - Minimum visit count (default: 3)
- `max_total_engagement` - Maximum total engagement in minutes (default: 5)

**Example**:
```
http://localhost:3000/api/v1/pattern_detections/serial_openers?min_visits=3&max_total_engagement=10
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "serial_openers": [
      {
        "page_visit_id": "pv_2",
        "url": "https://stackoverflow.com/questions/react-hooks",
        "title": "React Hooks Questions - Stack Overflow",
        "domain": "stackoverflow.com",
        "visit_count": 3,
        "total_engagement_seconds": 600,
        "avg_engagement_per_visit": 200.0,
        "first_visit_at": "2025-01-20T14:35:00.000Z",
        "last_visit_at": "2025-01-20T14:35:00.000Z",
        "engagement_rate": 0.7,
        "suggested_action": "save_to_reading_list"
      }
    ],
    "count": 1,
    "criteria": {
      "min_visits": 3,
      "max_total_engagement_minutes": 10
    }
  }
}
```

### 3.3 Detect Research Sessions

Groups browsing bursts into restorable sessions.

**GET** `http://localhost:3000/`api/v1/pattern_detections/research_sessions``

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Query Parameters** (optional):
- `min_tabs` - Minimum tabs in session (default: 3)
- `time_window` - Time window in minutes (default: 15)
- `min_duration` - Minimum session duration in minutes (default: 10)

**Example**:
```
http://localhost:3000/api/v1/pattern_detections/research_sessions?min_tabs=3&time_window=20
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "research_sessions": [
      {
        "session_name": "Reactjs - Jan 20, 02:30PM",
        "session_start": "2025-01-20T14:30:00.000Z",
        "session_end": "2025-01-20T14:45:00.000Z",
        "tab_count": 4,
        "primary_domain": "reactjs.org",
        "domains": ["reactjs.org", "stackoverflow.com", "medium.com", "github.com"],
        "total_duration_seconds": 4080,
        "avg_engagement_rate": 0.475,
        "page_visit_ids": ["pv_1", "pv_2", "pv_3", "pv_4"],
        "status": "detected"
      }
    ],
    "count": 1,
    "criteria": {
      "min_tabs": 3,
      "time_window_minutes": 20,
      "min_duration_minutes": 10
    }
  }
}
```

---

## 4. Reading List APIs

### 4.1 Add Item to Reading List

**POST** `http://localhost:3000/api/v1/reading_list_items`

**Headers**:
```
Authorization: Bearer {{access_token}}
Content-Type: application/json
```

**Body** (raw JSON):
```json
{
  "reading_list_item": {
    "page_visit_id": "pv_1",
    "url": "https://reactjs.org/docs/hooks-intro.html",
    "title": "Introducing Hooks - React",
    "domain": "reactjs.org",
    "added_from": "hoarder_detection",
    "status": "unread",
    "estimated_read_time": 300,
    "notes": "Need to review useState and useEffect examples",
    "tags": ["react", "javascript", "hooks"]
  }
}
```

**Expected Response** (201 Created):
```json
{
  "success": true,
  "message": "Item added to reading list",
  "data": {
    "reading_list_item": {
      "id": 1,
      "user_id": 1,
      "page_visit_id": "pv_1",
      "url": "https://reactjs.org/docs/hooks-intro.html",
      "title": "Introducing Hooks - React",
      "domain": "reactjs.org",
      "added_at": "2025-01-22T10:00:00.000Z",
      "added_from": "hoarder_detection",
      "status": "unread",
      "estimated_read_time": 300,
      "notes": "Need to review useState and useEffect examples",
      "tags": ["react", "javascript", "hooks"],
      "estimated_read_minutes": 5
    }
  }
}
```

### 4.2 List Reading List Items

**GET** `http://localhost:3000/api/v1/reading_list_items`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Query Parameters** (optional):
- `status` - Filter by status: unread, reading, completed, dismissed
- `tags` - Filter by tags (comma-separated): react,javascript
- `limit` - Number of items to return (default: 100)

**Examples**:
```
http://localhost:3000/api/v1/reading_list_items
http://localhost:3000/api/v1/reading_list_items?status=unread
http://localhost:3000/api/v1/reading_list_items?tags=react,javascript
http://localhost:3000/api/v1/reading_list_items?status=unread&limit=10
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "reading_list_items": [
      {
        "id": 1,
        "url": "https://reactjs.org/docs/hooks-intro.html",
        "title": "Introducing Hooks - React",
        "status": "unread",
        "estimated_read_minutes": 5,
        "tags": ["react", "javascript", "hooks"],
        "added_at": "2025-01-22T10:00:00.000Z"
      }
    ],
    "count": 1
  }
}
```

### 4.3 Get Single Reading List Item

**GET** `http://localhost:3000/api/v1/reading_list_items/:id`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Example**:
```
http://localhost:3000/api/v1/reading_list_items/1
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "reading_list_item": {
      "id": 1,
      "url": "https://reactjs.org/docs/hooks-intro.html",
      "title": "Introducing Hooks - React",
      "domain": "reactjs.org",
      "status": "unread",
      "estimated_read_minutes": 5,
      "notes": "Need to review useState and useEffect examples",
      "tags": ["react", "javascript", "hooks"],
      "added_at": "2025-01-22T10:00:00.000Z"
    }
  }
}
```

### 4.4 Update Reading List Item

**PATCH** `http://localhost:3000/api/v1/reading_list_items/:id`

**Headers**:
```
Authorization: Bearer {{access_token}}
Content-Type: application/json
```

**Body** (raw JSON):
```json
{
  "reading_list_item": {
    "notes": "Updated notes after reading",
    "tags": ["react", "javascript", "hooks", "tutorial"],
    "scheduled_for": "2025-01-25T09:00:00Z"
  }
}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Reading list item updated",
  "data": {
    "reading_list_item": {
      "id": 1,
      "notes": "Updated notes after reading",
      "tags": ["react", "javascript", "hooks", "tutorial"],
      "scheduled_for": "2025-01-25T09:00:00.000Z"
    }
  }
}
```

### 4.5 Mark as Reading

**POST** `http://localhost:3000/api/v1/reading_list_items/:id/mark_reading`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Example**:
```
http://localhost:3000/api/v1/reading_list_items/1/mark_reading
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Item marked as reading",
  "data": {
    "reading_list_item": {
      "id": 1,
      "status": "reading"
    }
  }
}
```

### 4.6 Mark as Completed

**POST** `http://localhost:3000/api/v1/reading_list_items/:id/mark_completed`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Item marked as completed",
  "data": {
    "reading_list_item": {
      "id": 1,
      "status": "completed",
      "completed_at": "2025-01-22T10:30:00.000Z"
    }
  }
}
```

### 4.7 Mark as Dismissed

**POST** `http://localhost:3000/api/v1/reading_list_items/:id/mark_dismissed`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Item marked as dismissed",
  "data": {
    "reading_list_item": {
      "id": 1,
      "status": "dismissed",
      "dismissed_at": "2025-01-22T10:35:00.000Z"
    }
  }
}
```

### 4.8 Delete Reading List Item

**DELETE** `http://localhost:3000/api/v1/reading_list_items/:id`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Reading list item removed"
}
```

---

## 5. Research Sessions APIs

### 5.1 Create Research Session

**POST** `http://localhost:3000/api/v1/research_sessions`

**Headers**:
```
Authorization: Bearer {{access_token}}
Content-Type: application/json
```

**Body** (raw JSON):
```json
{
  "research_session": {
    "session_name": "React Hooks Research",
    "session_start": "2025-01-20T14:30:00Z",
    "session_end": "2025-01-20T14:45:00Z",
    "tab_count": 4,
    "primary_domain": "reactjs.org",
    "domains": ["reactjs.org", "stackoverflow.com", "medium.com", "github.com"],
    "topics": ["react", "hooks", "javascript"],
    "total_duration_seconds": 4080,
    "avg_engagement_rate": 0.475,
    "status": "detected"
  },
  "page_visit_ids": ["pv_1", "pv_2", "pv_3", "pv_4"]
}
```

**Expected Response** (201 Created):
```json
{
  "success": true,
  "message": "Research session created",
  "data": {
    "research_session": {
      "id": 1,
      "session_name": "React Hooks Research",
      "session_start": "2025-01-20T14:30:00.000Z",
      "session_end": "2025-01-20T14:45:00.000Z",
      "tab_count": 4,
      "primary_domain": "reactjs.org",
      "domains": ["reactjs.org", "stackoverflow.com", "medium.com", "github.com"],
      "topics": ["react", "hooks", "javascript"],
      "status": "detected",
      "research_session_tabs": [
        {
          "id": 1,
          "page_visit_id": "pv_1",
          "url": "https://reactjs.org/docs/hooks-intro.html",
          "title": "Introducing Hooks - React",
          "tab_order": 1
        },
        {
          "id": 2,
          "page_visit_id": "pv_2",
          "url": "https://stackoverflow.com/questions/react-hooks",
          "title": "React Hooks Questions - Stack Overflow",
          "tab_order": 2
        }
      ]
    }
  }
}
```

### 5.2 List Research Sessions

**GET** `http://localhost:3000/api/v1/research_sessions`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Query Parameters** (optional):
- `status` - Filter by status: detected, saved, restored, dismissed
- `domain` - Filter by primary domain
- `start_date` - Filter by start date (ISO 8601)
- `end_date` - Filter by end date (ISO 8601)
- `limit` - Number of sessions to return (default: 50)

**Examples**:
```
http://localhost:3000/api/v1/research_sessions
http://localhost:3000/api/v1/research_sessions?status=detected
http://localhost:3000/api/v1/research_sessions?domain=reactjs.org
http://localhost:3000/api/v1/research_sessions?start_date=2025-01-20T00:00:00Z&end_date=2025-01-21T00:00:00Z
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "research_sessions": [
      {
        "id": 1,
        "session_name": "React Hooks Research",
        "session_start": "2025-01-20T14:30:00.000Z",
        "session_end": "2025-01-20T14:45:00.000Z",
        "tab_count": 4,
        "primary_domain": "reactjs.org",
        "status": "detected",
        "formatted_duration": "15 min",
        "research_session_tabs": [
          {
            "id": 1,
            "url": "https://reactjs.org/docs/hooks-intro.html",
            "title": "Introducing Hooks - React",
            "domain": "reactjs.org",
            "tab_order": 1
          }
        ]
      }
    ],
    "count": 1
  }
}
```

### 5.3 Get Single Research Session

**GET** `http://localhost:3000/api/v1/research_sessions/:id`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Example**:
```
http://localhost:3000/api/v1/research_sessions/1
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "research_session": {
      "id": 1,
      "session_name": "React Hooks Research",
      "session_start": "2025-01-20T14:30:00.000Z",
      "session_end": "2025-01-20T14:45:00.000Z",
      "tab_count": 4,
      "primary_domain": "reactjs.org",
      "domains": ["reactjs.org", "stackoverflow.com", "medium.com", "github.com"],
      "topics": ["react", "hooks", "javascript"],
      "total_duration_seconds": 4080,
      "avg_engagement_rate": 0.475,
      "status": "detected",
      "formatted_duration": "15 min",
      "research_session_tabs": [
        {
          "id": 1,
          "url": "https://reactjs.org/docs/hooks-intro.html",
          "title": "Introducing Hooks - React",
          "domain": "reactjs.org",
          "tab_order": 1
        },
        {
          "id": 2,
          "url": "https://stackoverflow.com/questions/react-hooks",
          "title": "React Hooks Questions - Stack Overflow",
          "domain": "stackoverflow.com",
          "tab_order": 2
        }
      ]
    }
  }
}
```

### 5.4 Save Research Session

**POST** `http://localhost:3000/api/v1/research_sessions/:id/save`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Example**:
```
http://localhost:3000/api/v1/research_sessions/1/save
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Research session saved",
  "data": {
    "research_session": {
      "id": 1,
      "status": "saved",
      "saved_at": "2025-01-22T10:45:00.000Z"
    }
  }
}
```

### 5.5 Restore Research Session

**POST** `http://localhost:3000/api/v1/research_sessions/:id/restore`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Example**:
```
http://localhost:3000/api/v1/research_sessions/1/restore
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Research session restored",
  "data": {
    "research_session": {
      "id": 1,
      "status": "restored",
      "last_restored_at": "2025-01-22T10:50:00.000Z",
      "restore_count": 1
    },
    "tabs": [
      {
        "url": "https://reactjs.org/docs/hooks-intro.html",
        "title": "Introducing Hooks - React",
        "tab_order": 1
      },
      {
        "url": "https://stackoverflow.com/questions/react-hooks",
        "title": "React Hooks Questions - Stack Overflow",
        "tab_order": 2
      }
    ]
  }
}
```

### 5.6 Dismiss Research Session

**POST** `http://localhost:3000/api/v1/research_sessions/:id/dismiss`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Research session dismissed",
  "data": {
    "research_session": {
      "id": 1,
      "status": "dismissed"
    }
  }
}
```

### 5.7 Update Research Session

**PATCH** `http://localhost:3000/api/v1/research_sessions/:id`

**Headers**:
```
Authorization: Bearer {{access_token}}
Content-Type: application/json
```

**Body** (raw JSON):
```json
{
  "research_session": {
    "session_name": "React Hooks Deep Dive - Updated",
    "topics": ["react", "hooks", "javascript", "frontend"]
  }
}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Research session updated",
  "data": {
    "research_session": {
      "id": 1,
      "session_name": "React Hooks Deep Dive - Updated",
      "topics": ["react", "hooks", "javascript", "frontend"]
    }
  }
}
```

### 5.8 Delete Research Session

**DELETE** `http://localhost:3000/api/v1/research_sessions/:id`

**Headers**:
```
Authorization: Bearer {{access_token}}
```

**Expected Response** (200 OK):
```json
{
  "success": true,
  "message": "Research session removed"
}
```

---

## 6. Common Error Responses

### 401 Unauthorized
Missing or invalid access token:
```json
{
  "error": "You need to sign in or sign up before continuing."
}
```

### 404 Not Found
Resource doesn't exist:
```json
{
  "success": false,
  "message": "Reading list item not found"
}
```

### 422 Unprocessable Entity
Validation errors:
```json
{
  "success": false,
  "message": "Failed to add item to reading list",
  "errors": [
    "Url can't be blank",
    "Url has already been taken"
  ]
}
```

### 500 Internal Server Error
Server error:
```json
{
  "success": false,
  "message": "Failed to detect hoarder tabs",
  "errors": [
    "Internal server error message"
  ]
}
```

---

## 7. Testing Workflow Example

Here's a complete workflow to test the full Phase 3 feature:

1. **Register & Login** → Get access token
2. **Sync browsing data** → Create page visits
3. **Detect hoarder tabs** → Find tabs to save
4. **Add to reading list** → Save a hoarder tab
5. **Mark as reading** → Update status
6. **Detect research sessions** → Group related tabs
7. **Create research session** → Save session from detection
8. **Restore session** → Get tabs to reopen
9. **List reading list** → See all saved items
10. **Mark as completed** → Finish reading

---

## 8. Postman Collection Import

You can create a Postman collection with all these endpoints. Here's the structure:

```
HeyHo Phase 3 APIs/
├── Authentication/
│   ├── Register
│   └── Login
├── Pattern Detection/
│   ├── Detect Hoarder Tabs
│   ├── Detect Serial Openers
│   └── Detect Research Sessions
├── Reading List/
│   ├── Add Item
│   ├── List Items
│   ├── Get Item
│   ├── Update Item
│   ├── Mark Reading
│   ├── Mark Completed
│   ├── Mark Dismissed
│   └── Delete Item
└── Research Sessions/
    ├── Create Session
    ├── List Sessions
    ├── Get Session
    ├── Save Session
    ├── Restore Session
    ├── Dismiss Session
    ├── Update Session
    └── Delete Session
```

---

## 9. Tips & Best Practices

1. **Use Environment Variables**: Store `base_url` and `access_token` in Postman environment
2. **Token Expiry**: Access tokens expire in 15 minutes - login again if you get 401
3. **Test Order**: Follow the workflow order above for best results
4. **Clean Data**: Use DELETE endpoints to clean up test data between runs
5. **Console Logs**: Check Rails logs for debugging: `docker-compose logs -f app`

---

## 10. Troubleshooting

**Problem**: "You need to sign in or sign up"
- **Solution**: Check Authorization header has correct token format: `Bearer {{token}}`

**Problem**: "Reading list item not found"
- **Solution**: Verify the ID exists by listing all items first

**Problem**: Empty results in pattern detection
- **Solution**: Make sure you synced page visits with appropriate data (duration, engagement, visit count)

**Problem**: Database connection errors
- **Solution**: Ensure Docker containers are running: `docker-compose ps`

---

Happy testing! 🚀
