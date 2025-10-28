# frozen_string_literal: true

# Seed data for testing hoarder detection
# Run with: rails runner db/seeds/hoarder_test_data.rb

puts '🌱 Starting hoarder detection test data generation...'
puts ''

# Find or create demo user
user = User.find_or_create_by!(email: 'demo@syrupy.com') do |u|
  u.first_name = 'Demo'
  u.last_name = 'User'
  u.password_hash = BCrypt::Password.create('password123')
  u.status = :verified
  u.isVerified = true
end

puts "👤 User: #{user.email} (ID: #{user.id})"

# Clear existing data for clean slate
# Delete tab aggregates first (foreign key constraint)
page_visit_ids = PageVisit.where(user_id: user.id).pluck(:id)
TabAggregate.where(page_visit_id: page_visit_ids).delete_all
PageVisit.where(user_id: user.id).delete_all
puts '🧹 Cleared existing page visits and tab aggregates'
puts ''

# Sample domains for realistic data
DOMAINS = {
  # Articles (likely to hoard)
  articles: [
    'medium.com',
    'dev.to',
    'hackernoon.com',
    'towardsdatascience.com',
    'freecodecamp.org'
  ],
  # Documentation (mixed)
  docs: [
    'docs.ruby-lang.org',
    'api.rubyonrails.org',
    'developer.mozilla.org',
    'stackoverflow.com'
  ],
  # Social (usually not hoarded long)
  social: [
    'twitter.com',
    'reddit.com',
    'news.ycombinator.com'
  ],
  # Shopping (sometimes hoarded)
  shopping: [
    'amazon.com',
    'ebay.com',
    'etsy.com'
  ],
  # Productivity (usually stay open)
  productivity: [
    'github.com',
    'gmail.com',
    'calendar.google.com',
    'notion.so',
    'figma.com'
  ]
}.freeze

def random_title(domain)
  prefixes = [
    'How to',
    'Understanding',
    'Complete Guide to',
    'Introduction to',
    'Best Practices for',
    'Tutorial:',
    'Learn',
    'Advanced',
    '10 Tips for'
  ]
  topics = [
    'Ruby on Rails',
    'JavaScript',
    'React Development',
    'Database Design',
    'API Design',
    'Testing',
    'Performance',
    'Security',
    'DevOps',
    'Clean Code'
  ]

  case domain
  when /github/
    "#{['awesome-ruby', 'rails-best-practices', 'react-hooks', 'typescript-guide'].sample} - Repository"
  when /stackoverflow/
    "#{topics.sample} - Stack Overflow"
  when /amazon|ebay/
    "#{['Laptop', 'Keyboard', 'Monitor', 'Desk', 'Chair'].sample} - #{domain}"
  else
    "#{prefixes.sample} #{topics.sample}"
  end
end

# Category distribution
def random_category
  categories = {
    'programming' => 40,
    'documentation' => 20,
    'social' => 15,
    'shopping' => 10,
    'productivity' => 10,
    'entertainment' => 5
  }

  rand_val = rand(100)
  cumulative = 0
  categories.each do |category, weight|
    cumulative += weight
    return category if rand_val < cumulative
  end
  'programming'
end

puts '📊 Generating test scenarios...'
puts ''

# Track created data
created_visits = []
created_aggregates = []

# SCENARIO 1: Old tabs still open (SHOULD BE FLAGGED AS HOARDERS)
puts '1️⃣  Creating old tabs still open (classic hoarders)...'
base_timestamp = Time.now.to_i
10.times do |i|
  domain = DOMAINS[:articles].sample
  url = "https://#{domain}/article-#{rand(1000)}"

  # Create visit from 3-14 days ago
  days_old = rand(3..14)
  visited_at = days_old.days.ago

  visit = PageVisit.create!(
    id: "pv_#{base_timestamp}_#{i}_s1",
    user_id: user.id,
    url: url,
    title: random_title(domain),
    domain: domain,
    visited_at: visited_at,
    duration_seconds: rand(30..600),
    active_duration_seconds: rand(10..300),
    engagement_rate: rand(0.05..0.3),
    category: 'work_coding',
    category_confidence: rand(0.7..0.95)
  )

  # Create aggregate showing tab is still open
  total_time = rand(300..3600)
  TabAggregate.create!(
    id: SecureRandom.uuid,
    page_visit_id: visit.id,
    closed_at: nil, # Still open!
    total_time_seconds: total_time,
    active_time_seconds: (total_time * rand(0.2..0.5)).to_i,
    scroll_depth_percent: rand(10..50)
  )

  created_visits << visit
  created_aggregates << "#{domain} (#{days_old}d old, OPEN)"
end
puts "   ✅ Created #{created_visits.size} old open tabs"

# SCENARIO 2: Old tabs that were closed (SHOULD NOT BE FLAGGED)
puts '2️⃣  Creating old tabs that were closed...'
8.times do |i|
  domain = DOMAINS[:articles].sample
  url = "https://#{domain}/closed-article-#{rand(1000)}"

  days_old = rand(5..20)
  visited_at = days_old.days.ago
  closed_at = rand(1..3).days.ago

  visit = PageVisit.create!(
    id: "pv_#{base_timestamp}_#{i}_s2",
    user_id: user.id,
    url: url,
    title: random_title(domain),
    domain: domain,
    visited_at: visited_at,
    duration_seconds: rand(60..300),
    active_duration_seconds: rand(30..150),
    engagement_rate: rand(0.1..0.4),
    category: 'work_coding'
  )

  # Tab was closed recently
  total_time = rand(180..1200)
  TabAggregate.create!(
    id: SecureRandom.uuid,
    page_visit_id: visit.id,
    closed_at: closed_at, # Explicitly closed
    total_time_seconds: total_time,
    active_time_seconds: (total_time * rand(0.3..0.6)).to_i,
    scroll_depth_percent: rand(20..80)
  )

  created_visits << visit
  created_aggregates << "#{domain} (#{days_old}d old, CLOSED #{closed_at.to_date})"
end
puts "   ✅ Created #{8} closed tabs (should be excluded)"

# SCENARIO 3: Recent tabs still open (SHOULD NOT BE FLAGGED - too new)
puts '3️⃣  Creating recent tabs still open...'
5.times do |i|
  domain = DOMAINS[:docs].sample
  url = "https://#{domain}/docs/#{rand(100)}"

  hours_old = rand(1..48)
  visited_at = hours_old.hours.ago

  visit = PageVisit.create!(
    id: "pv_#{base_timestamp}_#{i}_s3",
    user_id: user.id,
    url: url,
    title: random_title(domain),
    domain: domain,
    visited_at: visited_at,
    duration_seconds: rand(120..600),
    active_duration_seconds: rand(60..400),
    engagement_rate: rand(0.3..0.7),
    category: 'work_documentation'
  )

  total_time = rand(300..1800)
  TabAggregate.create!(
    id: SecureRandom.uuid,
    page_visit_id: visit.id,
    closed_at: nil, # Still open
    total_time_seconds: total_time,
    active_time_seconds: (total_time * rand(0.5..0.7)).to_i,
    scroll_depth_percent: rand(30..90)
  )

  created_visits << visit
  created_aggregates << "#{domain} (#{hours_old}h old, OPEN - too recent)"
end
puts "   ✅ Created #{5} recent open tabs (too new to flag)"

# SCENARIO 4: Productivity tabs that stay open (MAY OR MAY NOT FLAG - depends on activity)
puts '4️⃣  Creating productivity tabs (always open)...'
3.times do |i|
  domain = DOMAINS[:productivity].sample
  url = "https://#{domain}/project-#{rand(10)}"

  days_old = rand(7..30)
  visited_at = days_old.days.ago

  # Multiple visits to same URL (shows active use)
  3.times do |j|
    visit = PageVisit.create!(
      id: "pv_#{base_timestamp}_#{i}_#{j}_s4",
      user_id: user.id,
      url: url,
      title: random_title(domain),
      domain: domain,
      visited_at: visited_at - rand(0..2).days,
      duration_seconds: rand(600..3600),
      active_duration_seconds: rand(400..2400),
      engagement_rate: rand(0.5..0.9),
      category: 'work_coding'
    )
    created_visits << visit
  end

  # Tab aggregate shows high activity
  total_time = rand(7200..86400)
  TabAggregate.create!(
    id: SecureRandom.uuid,
    page_visit_id: created_visits.last.id,
    closed_at: nil, # Productivity tabs stay open
    total_time_seconds: total_time,
    active_time_seconds: (total_time * rand(0.5..0.7)).to_i,
    scroll_depth_percent: rand(60..100)
  )

  created_aggregates << "#{domain} (#{days_old}d old, OPEN, HIGH ACTIVITY)"
end
puts "   ✅ Created #{3} productivity tabs (high activity)"

# SCENARIO 5: Very old single-visit tabs (STRONG HOARDER SIGNALS)
puts '5️⃣  Creating very old single-visit tabs (forgotten tabs)...'
15.times do |i|
  domain = (DOMAINS[:articles] + DOMAINS[:shopping]).sample
  url = "https://#{domain}/forgotten-#{rand(10000)}"

  weeks_old = rand(3..12)
  visited_at = weeks_old.weeks.ago

  visit = PageVisit.create!(
    id: "pv_#{base_timestamp}_#{i}_s5",
    user_id: user.id,
    url: url,
    title: random_title(domain),
    domain: domain,
    visited_at: visited_at,
    duration_seconds: rand(10..120), # Very short visit
    active_duration_seconds: rand(5..60),
    engagement_rate: rand(0.01..0.15), # Low engagement
    category: ['shopping', 'work_coding'].sample
  )

  total_time = rand(60..600)
  TabAggregate.create!(
    id: SecureRandom.uuid,
    page_visit_id: visit.id,
    closed_at: nil, # Still open!
    total_time_seconds: total_time,
    active_time_seconds: (total_time * rand(0.1..0.3)).to_i,
    scroll_depth_percent: rand(5..25) # Low scroll depth
  )

  created_visits << visit
  created_aggregates << "#{domain} (#{weeks_old}w old, SINGLE VISIT, LOW ENGAGEMENT)"
end
puts "   ✅ Created #{15} forgotten tabs (strongest hoarder signals)"

# SCENARIO 6: Tabs with unknown status (old format - no closure tracking)
puts '6️⃣  Creating tabs with unknown status (legacy data)...'
5.times do |i|
  domain = DOMAINS[:docs].sample
  url = "https://#{domain}/legacy-#{rand(100)}"

  days_old = rand(10..30)
  visited_at = days_old.days.ago

  visit = PageVisit.create!(
    id: "pv_#{base_timestamp}_#{i}_s6",
    user_id: user.id,
    url: url,
    title: random_title(domain),
    domain: domain,
    visited_at: visited_at,
    duration_seconds: rand(300..1800),
    active_duration_seconds: rand(150..900),
    engagement_rate: rand(0.2..0.5),
    category: 'work_documentation'
  )

  # Old format: no closedAt, no isOpen field (unknown status)
  total_time = rand(600..3600)
  TabAggregate.create!(
    id: SecureRandom.uuid,
    page_visit_id: visit.id,
    closed_at: nil, # Unknown if open or closed
    total_time_seconds: total_time,
    active_time_seconds: (total_time * rand(0.4..0.6)).to_i,
    scroll_depth_percent: rand(20..60)
  )

  created_visits << visit
  created_aggregates << "#{domain} (#{days_old}d old, STATUS UNKNOWN)"
end
puts "   ✅ Created #{5} tabs with unknown status"

puts ''
puts '✨ Summary:'
puts "   📄 Total PageVisits: #{created_visits.size}"
puts "   📊 Total TabAggregates: #{created_aggregates.size}"
puts ''

# Print statistics
total_with_closed_at = TabAggregate.where.not(closed_at: nil).count
total_without_closed_at = TabAggregate.where(closed_at: nil).count

puts '📈 Database Statistics:'
puts "   PageVisits: #{PageVisit.where(user_id: user.id).count}"
puts "   TabAggregates: #{TabAggregate.count}"
puts "   - With closed_at: #{total_with_closed_at} (excluded from detection)"
puts "   - Without closed_at: #{total_without_closed_at} (candidates for detection)"
puts ''

# Show expected hoarder detection results
expected_hoarders = [
  "✓ 10 old tabs (3-14 days) still open",
  "✓ 15 very old tabs (3-12 weeks) with single visit",
  "✓ 5 tabs with unknown status (10-30 days old)",
  "? 3 productivity tabs (depends on whitelist/scoring)"
].join("\n   ")

puts '🎯 Expected Hoarder Detection Results:'
puts "   #{expected_hoarders}"
puts ''
puts "   ✗ 8 closed tabs (should be excluded)"
puts "   ✗ 5 recent tabs (too new - < 3 days)"
puts ''

puts '🎉 Seed data generation complete!'
puts ''
puts '📝 Next steps:'
puts '   1. Run migration: make db-migrate'
puts '   2. Test hoarder detection: GET /api/v1/pattern_detections/hoarder_tabs'
puts '   3. Check that ~28-33 tabs are detected (not the 8 closed ones or 5 recent ones)'
puts ''
