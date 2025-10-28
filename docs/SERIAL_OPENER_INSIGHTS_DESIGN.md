# Serial Opener Insights - Rule-Based System Design

**Goal:** Generate meaningful behavioral insights from serial opener data WITHOUT using ML/LLM

## Current Data vs. Needed Data

### ✅ What We Currently Return

```json
{
  "page_visit_id": "pv_123",
  "url": "https://notion.so/page",
  "title": "Issue Tracker",
  "domain": "notion.so",
  "visit_count": 16,
  "total_engagement_seconds": 147,
  "avg_engagement_per_visit": 9.2,
  "first_visit_at": "2025-10-21T11:42:30Z",
  "last_visit_at": "2025-10-23T13:52:32Z",
  "engagement_rate": 0.166,
  "suggested_action": "save_to_reading_list"
}
```

### ❌ What's Missing for Insights

1. **Frequency metrics** - How often are they checking?
2. **Time patterns** - When do they check?
3. **Behavioral classification** - What type of behavior is this?
4. **Context** - Why are they doing this?
5. **Actionable suggestions** - What should they do?

---

## Rule-Based Insight Generation (No ML Needed!)

### 1. Frequency Pattern Analysis

**Calculation:**
```ruby
time_span_hours = (last_visit - first_visit) / 3600.0
avg_hours_between_visits = time_span_hours / visit_count
visits_per_day = (visit_count / (time_span_hours / 24.0))
```

**Rules:**
```
IF avg_hours_between_visits < 0.5 (30 min):
  → behavior_type = "compulsive_checking"
  → insight = "You're checking this multiple times per hour"
  → suggestion = "Enable notifications instead"

ELSE IF avg_hours_between_visits < 2:
  → behavior_type = "frequent_monitoring"
  → insight = "You check this several times per day"
  → suggestion = "Set specific check-in times"

ELSE IF avg_hours_between_visits < 8:
  → behavior_type = "regular_reference"
  → insight = "You reference this regularly throughout the day"
  → suggestion = "Pin this tab or bookmark it"

ELSE:
  → behavior_type = "periodic_revisit"
  → insight = "You come back to this occasionally"
  → suggestion = "Consider bookmarking instead of reopening"
```

**New fields to add:**
- `avg_hours_between_visits`
- `visits_per_day`
- `behavior_type`

---

### 2. Engagement Pattern Analysis

**Calculation:**
```ruby
avg_seconds_per_visit = total_engagement_seconds / visit_count
total_minutes = total_engagement_seconds / 60.0
```

**Rules:**
```
IF avg_seconds_per_visit < 5:
  → engagement_type = "quick_glance"
  → insight = "You barely look at this (#{avg_seconds_per_visit}s per visit)"

ELSE IF avg_seconds_per_visit < 15:
  → engagement_type = "brief_check"
  → insight = "Quick checks for updates or status"

ELSE IF avg_seconds_per_visit < 60:
  → engagement_type = "scan"
  → insight = "You scan for specific information"

ELSE:
  → engagement_type = "shallow_work"
  → insight = "Light work or reading"
```

**Efficiency calculation:**
```ruby
total_time_wasted = (visit_count * 5) # 5 seconds per tab open/close
efficiency = (total_engagement_seconds / (total_engagement_seconds + total_time_wasted)) * 100

IF efficiency < 50:
  → insight = "You spend more time opening/closing than actually using this"
```

**New fields to add:**
- `avg_seconds_per_visit`
- `engagement_type`
- `efficiency_score`

---

### 3. Time Pattern Analysis

**Calculation:**
```ruby
# Need to fetch all visits, not just summary
visits_by_hour = visits.group_by { |v| v.visited_at.hour }.transform_values(&:count)
peak_hours = visits_by_hour.sort_by { |h, c| -c }.first(3)

# Day of week pattern
visits_by_day = visits.group_by { |v| v.visited_at.strftime('%A') }.transform_values(&:count)
```

**Rules:**
```
IF peak_hours.all? { |hour, _| hour.between?(9, 17) }:
  → time_pattern = "work_hours"
  → insight = "You check this during work hours"

ELSE IF peak_hours.any? { |hour, _| hour.between?(22, 6) }:
  → time_pattern = "late_night"
  → insight = "You check this late at night"

IF visits_by_day.values.max > visits_by_day.values.min * 3:
  → insight = "Much more active on #{visits_by_day.max_by { |d, c| c }[0]}"
```

**New fields to add:**
- `peak_hours` (array of top 3 hours)
- `time_pattern`
- `most_active_day`

---

### 4. Domain + Category Intelligence

**Use existing category + domain + title to infer purpose:**

```ruby
DOMAIN_PATTERNS = {
  'notion.so' => {
    purpose: 'documentation/project_management',
    title_keywords: {
      'issue|tracker|ticket' => 'task_tracking',
      'meeting|notes' => 'note_taking',
      'doc|documentation' => 'reference'
    }
  },
  'github.com' => {
    purpose: 'code_development',
    title_keywords: {
      'pull request|pr' => 'code_review',
      'issues' => 'issue_tracking',
      'repositories|repos' => 'repo_browsing'
    }
  },
  'mail.google.com' => {
    purpose: 'email',
    behavior: 'compulsive_inbox_checking'
  },
  'x.com' => {
    purpose: 'social_media',
    behavior: 'doom_scrolling_check'
  }
}

def infer_purpose(domain, title, category)
  pattern = DOMAIN_PATTERNS[domain]

  if pattern
    # Check title keywords
    pattern[:title_keywords]&.each do |keywords, purpose|
      return purpose if title.match?(/#{keywords}/i)
    end

    return pattern[:purpose]
  end

  # Fallback to category
  category
end
```

**Rules:**
```
IF purpose == 'task_tracking' && behavior_type == 'compulsive_checking':
  → insight = "You're obsessively checking task updates"
  → suggestion = "Enable Slack/email notifications for task changes"

IF purpose == 'email' && behavior_type == 'compulsive_checking':
  → insight = "Compulsive inbox checking detected"
  → suggestion = "Turn on desktop notifications, stop manually checking"

IF purpose == 'social_media' && visits_per_day > 10:
  → insight = "Frequent social media checking (#{visits_per_day}x/day)"
  → suggestion = "Schedule specific check times (e.g., 10am, 3pm, 6pm)"

IF purpose == 'code_review' && avg_seconds_per_visit < 10:
  → insight = "Checking PR status frequently but not reviewing"
  → suggestion = "Enable GitHub notifications instead"
```

**New fields to add:**
- `inferred_purpose`
- `behavioral_insight`
- `actionable_suggestion`

---

### 5. URL Pattern Deduplication

**Problem:** Notion URLs with different query params are the same page

```
https://notion.so/page?v=view1
https://notion.so/page?v=view2
```

**Solution:**
```ruby
def normalize_url(url)
  uri = URI.parse(url)

  # Remove query params for certain domains
  if uri.host.include?('notion.so')
    # Keep only the path, remove view parameters
    base_id = uri.path.split('/').last.split('?').first
    "#{uri.scheme}://#{uri.host}#{uri.path.split(base_id).first}#{base_id}"
  elsif uri.host.include?('github.com')
    # GitHub: keep path but remove query params
    "#{uri.scheme}://#{uri.host}#{uri.path}"
  else
    url
  end
end
```

**Enhancement to service:**
```ruby
# In SerialOpenerDetectionService
def detect_serial_openers
  all_visits = PageVisit.where(user_id: @user.id)

  # Group by NORMALIZED URL instead of raw URL
  grouped_visits = all_visits.group_by { |v| normalize_url(v.url) }

  # Then detect patterns
  serial_openers = grouped_visits.filter_map do |normalized_url, visits|
    next if visits.size < @min_visits

    build_serial_opener(normalized_url, visits)
  end
end
```

**New field:**
- `normalized_url` (for grouping)
- `url_variations_count` (how many different URLs for same resource)

---

## Proposed Enhanced Data Structure

```json
{
  "page_visit_id": "pv_123",
  "url": "https://notion.so/issue-tracker",
  "normalized_url": "https://notion.so/issue-tracker",
  "url_variations_count": 10,
  "title": "Issue Tracker | Cloud Tickets",
  "domain": "notion.so",
  "category": "work_documentation",

  // Current metrics
  "visit_count": 16,
  "total_engagement_seconds": 147,
  "avg_engagement_per_visit": 9.2,
  "first_visit_at": "2025-10-21T11:42:30Z",
  "last_visit_at": "2025-10-23T13:52:32Z",

  // NEW: Frequency metrics
  "time_span_hours": 50.2,
  "avg_hours_between_visits": 0.3,
  "visits_per_day": 7.7,

  // NEW: Pattern classification
  "behavior_type": "compulsive_checking",
  "engagement_type": "brief_check",
  "inferred_purpose": "task_tracking",
  "time_pattern": "work_hours",
  "peak_hours": [17, 16, 11],
  "most_active_day": "Wednesday",

  // NEW: Insights (rule-based, no LLM)
  "behavioral_insight": "You're checking this task tracker 8 times per day, spending only 9 seconds each time. This suggests you're anxiously waiting for updates rather than actively working.",

  // NEW: Actionable suggestion
  "actionable_suggestion": "Enable Notion notifications or Slack integration for task updates. Stop manually checking every 30 minutes.",

  // NEW: Impact metrics
  "estimated_time_wasted_seconds": 80,
  "efficiency_score": 64.7,

  "suggested_action": "enable_notifications"
}
```

---

## Implementation Priority

### Phase 1: Essential Metrics (Easy)
- ✅ Already have: visit_count, first/last visit, total engagement
- 🔧 Add: time_span_hours, avg_hours_between_visits, visits_per_day
- 🔧 Add: avg_seconds_per_visit
- 🔧 Add: behavior_type (using frequency rules)
- 🔧 Add: engagement_type (using engagement rules)

**Effort:** ~2 hours

### Phase 2: Pattern Analysis (Medium)
- 🔧 Add: URL normalization logic
- 🔧 Add: peak_hours, time_pattern
- 🔧 Add: inferred_purpose (domain + title keywords)
- 🔧 Update: SerialOpenerDetectionService to group by normalized_url

**Effort:** ~4 hours

### Phase 3: Insight Generation (Medium)
- 🔧 Add: InsightGenerator service
- 🔧 Add: behavioral_insight (rule-based text generation)
- 🔧 Add: actionable_suggestion (rule-based recommendations)
- 🔧 Add: efficiency_score

**Effort:** ~6 hours

---

## Example Rule-Based Insight Templates

### Template System (No LLM needed!)

```ruby
class SerialOpenerInsightGenerator
  INSIGHT_TEMPLATES = {
    compulsive_checking: {
      task_tracking: "You're checking this task tracker {visits_per_day} times per day, spending only {avg_seconds} seconds each time. This suggests you're anxiously waiting for updates.",
      email: "You check your email {visits_per_day} times per day with {avg_seconds}s per visit. This is disrupting your focus.",
      social_media: "Checking {domain} {visits_per_day} times per day indicates compulsive behavior."
    },
    frequent_monitoring: {
      code_review: "You've checked this PR {visit_count} times. You're likely waiting for reviews or CI results.",
      default: "You check this {visits_per_day} times per day."
    }
  }

  SUGGESTION_TEMPLATES = {
    task_tracking: "Enable notifications for task changes instead of manually checking.",
    email: "Turn on desktop notifications. Schedule specific email check times (e.g., 10am, 2pm, 5pm).",
    social_media: "Set specific times to check social media. Consider app blockers during work hours.",
    code_review: "Enable GitHub email/Slack notifications for PR reviews and CI status."
  }

  def generate_insight(opener_data)
    template = INSIGHT_TEMPLATES.dig(
      opener_data[:behavior_type].to_sym,
      opener_data[:inferred_purpose].to_sym
    ) || INSIGHT_TEMPLATES.dig(
      opener_data[:behavior_type].to_sym,
      :default
    )

    # Replace template variables
    template.gsub(/{(\w+)}/) do |match|
      key = $1.to_sym
      format_value(opener_data[key])
    end
  end
end
```

---

## Summary: Do You Need ML?

### ❌ No ML Needed For:
- Frequency classification (simple thresholds)
- Engagement patterns (duration analysis)
- Time patterns (hour/day grouping)
- Purpose inference (domain + keyword matching)
- Insight generation (template-based)
- Suggestions (rule-based mapping)

### ✅ ML Would Help With:
- Predicting which tabs will become serial openers
- Clustering similar browsing patterns across users
- Anomaly detection (unusual behavior)
- Personalized threshold tuning
- Natural language insight generation (but templates work fine!)

### 🎯 Recommendation:

**Start with rule-based system** (outlined above). It will give you:
- 80% of the value
- 20% of the complexity
- Deterministic, explainable insights
- No training data needed
- No ML infrastructure

**Only consider ML if:**
- You have 1000+ users with diverse patterns
- Rule-based system isn't capturing edge cases
- You want predictive capabilities
- You want to auto-tune thresholds per user

---

## Next Steps

1. ✅ Enhance `SerialOpenerDetectionService` to include new metrics
2. ✅ Add URL normalization logic
3. ✅ Create `InsightGenerator` service with rule templates
4. ✅ Update API response to include insights
5. ✅ Frontend: Display insights in UI
6. 📊 Track which insights/suggestions users act on (for future optimization)
