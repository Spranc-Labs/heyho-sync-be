# Smart Adaptive Whitelisting System

## Overview

The smart whitelisting system learns which domains are part of each user's routine and automatically excludes them from hoarder tab detection. This prevents false positives where productivity tools, music apps, or frequently-used reference sites get flagged as "hoarder tabs".

## How It Works

### 1. Universal Whitelist (Hard-coded)
These domains are NEVER flagged for anyone:
- `mail.google.com` / `gmail.com`
- `calendar.google.com`
- `outlook.com` / `outlook.live.com`

**Why:** Email and calendars are universal productivity tools that everyone uses.

### 2. Personal Whitelist (Learned from Usage)
Each user gets a personalized whitelist based on their browsing patterns.

The `RoutineDetector` analyzes domains and calculates a **routine score** (0-100):

| Factor | Points | What It Measures |
|--------|--------|------------------|
| Visit Frequency | 0-40 | How often the domain is visited (20+ visits = 40 pts) |
| Consistency | 0-30 | Spread across days, not binge usage (20+ days = 30 pts) |
| Time Pattern | 0-20 | Regular time of day (60%+ at same hour = 20 pts) |
| Engagement Pattern | 0-10 | Brief visits = tool, long = content (< 5 min avg = 10 pts) |

**Threshold:** Domains scoring **70+** are added to personal whitelist.

### 3. Routine Types Detected

| Type | Criteria | Example |
|------|----------|---------|
| `work_tool` | Frequent (15+), brief (< 10 min), spread (10+ days) | Postman, Figma, Linear |
| `reference` | Very frequent (20+), very brief (< 5 min) | Stack Overflow, MDN Docs |
| `entertainment_routine` | Moderate frequency (8-20), time pattern | Spotify, YouTube Music |
| `routine_site` | General routine (score 70+) | Any other habitual site |

## Database Schema

```ruby
create_table :personal_whitelists do |t|
  t.references :user
  t.string :domain
  t.string :whitelist_reason  # 'work_tool', 'reference', 'entertainment_routine', 'manual'
  t.integer :routine_score
  t.datetime :detected_at
  t.datetime :last_verified_at
  t.boolean :is_active
end
```

## Background Job: RefreshPersonalWhitelistsJob

Runs daily for each user to keep whitelists fresh:

1. **Analyze top 20 domains** from last 30 days
2. **Detect routines** using RoutineDetector
3. **Add new entries** if routine score >= 70
4. **Remove stale entries** if no longer routine

**Schedule:** Daily via cron or scheduler

```ruby
# Run for all users
User.find_each do |user|
  RefreshPersonalWhitelistsJob.perform_later(user.id)
end
```

## Usage in Hoarder Detection

When analyzing a tab, the system:

1. Checks **universal whitelist** first
2. Checks **personal whitelist** for the user
3. If whitelisted → **Exclude from hoarder detection**
4. If not whitelisted → Apply normal hoarder scoring

## Example Results

### Before Smart Whitelisting
```
Hoarder tabs detected: 479
Including:
- Gmail (4 tabs)
- Postman (2 tabs)
- Notion (116 tabs)
```

### After Smart Whitelisting
```
Hoarder tabs detected: 180
Excluded:
- Gmail (universal whitelist)
- Postman (work_tool, score: 85)
- YouTube Music (entertainment_routine, score: 72)
```

## Manual Whitelisting (Optional Future Feature)

Users can manually add domains to whitelist:

```ruby
PersonalWhitelist.add_or_update(
  user: current_user,
  domain: 'example.com',
  reason: 'manual',
  score: nil
)
```

Manual entries are never auto-removed.

## Testing

```ruby
# Detect if a domain is routine
result = Insights::RoutineDetector.detect(
  user: user,
  domain: 'github.com',
  lookback_days: 30
)

# => {
#   is_routine: true,
#   routine_type: 'work_tool',
#   score: 85,
#   breakdown: { visit_frequency: 40, consistency: 30, ... }
# }

# Check if whitelisted
PersonalWhitelist.whitelisted?(user: user, domain: 'github.com')
# => true

# Refresh whitelist for a user
RefreshPersonalWhitelistsJob.perform_now(user.id)
```

## Migration

```bash
rails db:migrate
```

This creates the `personal_whitelists` table.

## Benefits

1. **No false positives** - Work tools aren't flagged as hoarders
2. **Personalized** - Learns YOUR patterns, not generic rules
3. **Adaptive** - Updates as your habits change
4. **Transparent** - Shows why domains are whitelisted
5. **Low maintenance** - Runs automatically, no user input needed

