# Phase 3: Smart Resource Aggregator - Implementation Plan

## 🎯 What We're Building

4 core features to help ADHD users manage browsing habits:
1. **Hoarder Tabs** 📚 - Tabs open long with minimal engagement
2. **Serial Openers** 🔄 - Repeatedly opened but unfinished resources
3. **Research Sessions** 🐇 - Grouped browsing bursts for restoration
4. **Reading List** 📖 - Universal save-for-later system

---

## ✅ What We Already Have

**No new browser tracking needed!** All features use existing `page_visits` data:
- `duration_seconds` - How long tab was open
- `engagement_rate` - % of time actively engaged
- `visited_at` - Timestamp
- `domain`, `url`, `title` - Content identification

**Detection queries tested and working:**
- ✅ Hoarder tabs: Found 14 tabs
- ✅ Serial openers: Found 52 domains
- ✅ Research sessions: Found 101 sessions

---

## 📦 Implementation Chunks

### **Chunk 1: Database Foundation** ⏱️ 2-3 hours
Create 3 new tables with migrations

**Files to create:**
- `db/migrate/YYYYMMDDHHMMSS_create_reading_list_items.rb`
- `db/migrate/YYYYMMDDHHMMSS_create_research_sessions.rb`
- `db/migrate/YYYYMMDDHHMMSS_create_research_session_tabs.rb`

**Tasks:**
- [ ] Create reading_list_items migration
- [ ] Create research_sessions migration
- [ ] Create research_session_tabs migration
- [ ] Run migrations in development
- [ ] Verify schema in psql
- [ ] Run migrations in test environment

**Success Criteria:**
- All 3 tables exist in database
- All indexes created
- Foreign keys working
- Schema matches specification

---

### **Chunk 2: Models & Validations** ⏱️ 3-4 hours
Create ActiveRecord models with validations

**Files to create:**
- `app/models/reading_list_item.rb`
- `app/models/research_session.rb`
- `app/models/research_session_tab.rb`
- `spec/models/reading_list_item_spec.rb`
- `spec/models/research_session_spec.rb`
- `spec/models/research_session_tab_spec.rb`

**Tasks:**
- [ ] Create ReadingListItem model
- [ ] Create ResearchSession model
- [ ] Create ResearchSessionTab model
- [ ] Add associations (belongs_to, has_many)
- [ ] Add validations
- [ ] Add scopes (active, unread, recent, etc.)
- [ ] Write model specs
- [ ] Run specs to verify

**Success Criteria:**
- All models pass validation tests
- Associations work correctly
- Scopes return expected results
- 90%+ test coverage for models

---

### **Chunk 3: Detection Services** ⏱️ 4-5 hours
SQL detection logic wrapped in service objects

**Files to create:**
- `app/services/patterns/hoarder_detector.rb`
- `app/services/patterns/serial_opener_detector.rb`
- `app/services/patterns/research_session_detector.rb`
- `spec/services/patterns/hoarder_detector_spec.rb`
- `spec/services/patterns/serial_opener_detector_spec.rb`
- `spec/services/patterns/research_session_detector_spec.rb`

**Tasks:**
- [ ] Create Patterns::HoarderDetector service
- [ ] Create Patterns::SerialOpenerDetector service
- [ ] Create Patterns::ResearchSessionDetector service
- [ ] Add suggestion generation algorithms
- [ ] Add customizable thresholds
- [ ] Write service specs with test data
- [ ] Test with real user data in console

**Success Criteria:**
- All 3 detectors return formatted results
- Suggestions are contextual and helpful
- Queries execute in < 100ms
- Service specs pass with test data

---

### **Chunk 4: Pattern Detection APIs** ⏱️ 3-4 hours
Read-only endpoints to expose detected patterns

**Files to create:**
- `app/controllers/api/v1/patterns_controller.rb`
- `config/routes.rb` (add routes)
- `spec/requests/api/v1/patterns_spec.rb`

**Endpoints:**
- `GET /api/v1/patterns/hoarder-tabs`
- `GET /api/v1/patterns/serial-openers`
- `GET /api/v1/patterns/research-sessions`
- `GET /api/v1/patterns/summary` (counts only)

**Tasks:**
- [ ] Create PatternsController
- [ ] Implement hoarder_tabs action
- [ ] Implement serial_openers action
- [ ] Implement research_sessions action
- [ ] Implement summary action
- [ ] Add pagination support
- [ ] Add filtering params (domain, date range)
- [ ] Write request specs
- [ ] Test with Postman/curl

**Success Criteria:**
- All endpoints return 200 with valid data
- Pagination works correctly
- Filters work as expected
- Request specs cover all scenarios

---

### **Chunk 5: Reading List CRUD** ⏱️ 4-5 hours
Full CRUD for reading list management

**Files to create:**
- `app/controllers/api/v1/reading_list_controller.rb`
- `config/routes.rb` (add routes)
- `spec/requests/api/v1/reading_list_spec.rb`
- `spec/factories/reading_list_items.rb`

**Endpoints:**
- `GET /api/v1/reading-list` - List all items
- `POST /api/v1/reading-list` - Create item
- `POST /api/v1/reading-list/bulk` - Bulk create
- `PATCH /api/v1/reading-list/:id` - Update item
- `DELETE /api/v1/reading-list/:id` - Delete item
- `PATCH /api/v1/reading-list/:id/complete` - Mark as read
- `PATCH /api/v1/reading-list/:id/dismiss` - Dismiss

**Tasks:**
- [ ] Create ReadingListController
- [ ] Implement index (with filters)
- [ ] Implement create
- [ ] Implement bulk create
- [ ] Implement update
- [ ] Implement destroy
- [ ] Implement complete action
- [ ] Implement dismiss action
- [ ] Add strong parameters
- [ ] Write request specs
- [ ] Test all CRUD operations

**Success Criteria:**
- All CRUD operations work
- Bulk create handles 50+ items
- Duplicate URL detection works
- Request specs cover all edge cases

---

### **Chunk 6: Research Sessions CRUD** ⏱️ 5-6 hours
Full lifecycle management for research sessions

**Files to create:**
- `app/controllers/api/v1/research_sessions_controller.rb`
- `app/services/research_session_creator.rb`
- `app/services/research_session_restorer.rb`
- `config/routes.rb` (add routes)
- `spec/requests/api/v1/research_sessions_spec.rb`
- `spec/factories/research_sessions.rb`
- `spec/factories/research_session_tabs.rb`

**Endpoints:**
- `GET /api/v1/research-sessions` - List sessions
- `GET /api/v1/research-sessions/:id` - Show session with tabs
- `POST /api/v1/research-sessions` - Create session
- `POST /api/v1/research-sessions/:id/save` - Save detected session
- `POST /api/v1/research-sessions/:id/restore` - Restore tabs
- `PATCH /api/v1/research-sessions/:id` - Update session
- `DELETE /api/v1/research-sessions/:id` - Delete session

**Tasks:**
- [ ] Create ResearchSessionsController
- [ ] Create ResearchSessionCreator service
- [ ] Create ResearchSessionRestorer service
- [ ] Implement index (with filters)
- [ ] Implement show (with tabs)
- [ ] Implement create
- [ ] Implement save action
- [ ] Implement restore action
- [ ] Implement update
- [ ] Implement destroy
- [ ] Write request specs
- [ ] Test session creation from detection
- [ ] Test restore flow

**Success Criteria:**
- All CRUD operations work
- Save action creates session + tabs
- Restore returns tab list in order
- Request specs cover all scenarios

---

### **Chunk 7: Comprehensive Testing** ⏱️ 4-5 hours
Ensure everything works together

**Tasks:**
- [ ] Review all model specs
- [ ] Review all service specs
- [ ] Review all request specs
- [ ] Add integration tests
- [ ] Test with real user data
- [ ] Check test coverage (target: 90%+)
- [ ] Fix any failing tests
- [ ] Add edge case tests
- [ ] Performance test detection queries
- [ ] Load test API endpoints

**Success Criteria:**
- All specs passing
- 90%+ test coverage
- No N+1 queries
- All endpoints < 200ms response time
- Detection queries < 100ms

---

## 📅 Implementation Timeline

**Week 1: Foundation & Detection**
- Day 1: Chunk 1 (Migrations)
- Day 2: Chunk 2 (Models)
- Day 3: Chunk 3 (Detection Services)
- Day 4: Chunk 4 (Pattern APIs)

**Week 2: CRUD Operations**
- Day 5-6: Chunk 5 (Reading List)
- Day 7-8: Chunk 6 (Research Sessions)
- Day 9: Chunk 7 (Testing)

**Total Estimate:** 25-30 hours (1.5-2 weeks at 4 hours/day)

---

## 🧪 Testing Strategy

### Test Data Setup
```ruby
# Create test user with browsing data
user = create(:user)

# Create hoarder tabs (open long, low engagement)
create_list(:page_visit, 10,
  user: user,
  duration_seconds: 3600,  # 1 hour
  engagement_rate: 0.02     # 2%
)

# Create serial opener pattern
5.times do
  create(:page_visit,
    user: user,
    domain: 'medium.com',
    duration_seconds: 45,    # < 1 minute
    visited_at: rand(30).days.ago
  )
end

# Create research session pattern
10.times do |i|
  create(:page_visit,
    user: user,
    domain: 'stackoverflow.com',
    visited_at: 2.hours.ago + i.minutes
  )
end
```

### API Testing with cURL
```bash
# Get JWT token
TOKEN=$(docker-compose exec app rails runner "
  user = User.first
  puts Authentication::TokenService.generate_jwt_token(user)
")

# Test hoarder tabs
curl -X GET "http://localhost:3000/api/v1/patterns/hoarder-tabs" \
  -H "Authorization: Bearer $TOKEN"

# Create reading list item
curl -X POST "http://localhost:3000/api/v1/reading-list" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "reading_list_item": {
      "url": "https://example.com/article",
      "title": "Test Article",
      "added_from": "manual_save"
    }
  }'
```

---

## 🚀 Getting Started

```bash
# 1. Ensure you're on correct branch
git checkout -b feature/phase-3-smart-resources

# 2. Start with Chunk 1
# Create first migration...

# 3. Run migrations
docker-compose exec app rails db:migrate

# 4. Verify in console
docker-compose exec app rails console
> ActiveRecord::Base.connection.tables
# Should see: reading_list_items, research_sessions, research_session_tabs

# 5. Continue with next chunks...
```

---

## 📊 Success Metrics

### Technical Metrics
- [ ] All 3 tables created
- [ ] All 3 models with validations
- [ ] All 3 detection services working
- [ ] 17 API endpoints implemented
- [ ] 90%+ test coverage
- [ ] All queries < 100ms
- [ ] All API responses < 200ms

### Functional Metrics
- [ ] Hoarder detection finds tabs
- [ ] Serial opener detection finds domains
- [ ] Research sessions grouped correctly
- [ ] Reading list saves items
- [ ] Research sessions restore tabs
- [ ] No duplicate URLs in reading list
- [ ] Sessions save with correct tab order

---

## 🔄 Next Steps After Phase 3

1. **Browser Extension Integration**
   - Show pattern counts in popup
   - Add "Save to Reading List" button
   - Add "Restore Session" action

2. **Web Dashboard**
   - Reading list management UI
   - Research sessions archive
   - Pattern insights/stats

3. **Enhanced Features (Phase 4)**
   - Smart reminders
   - Weekly digest emails
   - Pattern learning (ML)
   - Reading time estimates

---

**Status:** Ready to Begin
**Current Chunk:** Chunk 1 (Database Migrations)
**Last Updated:** 2025-10-22
