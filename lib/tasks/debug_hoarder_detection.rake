# frozen_string_literal: true

namespace :debug do
  desc 'Debug hoarder tab detection for a specific user'
  task hoarder_detection: :environment do
    email = ENV['EMAIL'] || 'test@example.com'
    user = User.find_by(email:)

    unless user
      puts "❌ User not found with email: #{email}"
      puts 'Usage: EMAIL=user@example.com bundle exec rake debug:hoarder_detection'
      exit 1
    end

    puts "\n#{"=" * 80}"
    puts '🔍 HOARDER TAB DETECTION DEBUG REPORT'
    puts '=' * 80
    puts "User: #{user.email} (ID: #{user.id})"
    puts "Current Time: #{Time.current}"
    puts '=' * 80

    # Step 1: Check total PageVisits
    total_visits = PageVisit.where(user_id: user.id).count
    puts "\n📊 STEP 1: PageVisit Records"
    puts '-' * 80
    puts "Total PageVisits: #{total_visits}"

    if total_visits.zero?
      puts "\n❌ NO PAGE VISITS FOUND!"
      puts '   Cause: Database is empty for this user'
      puts '   Fix: Sync browser data using the browser extension'
      exit 0
    end

    # Step 2: Check date ranges
    lookback_date = 30.days.ago
    within_lookback = PageVisit.where(user_id: user.id)
      .where('visited_at >= ?', lookback_date)
      .count

    puts "Within 30-day lookback: #{within_lookback}"

    if within_lookback.zero?
      puts "\n❌ NO VISITS IN LOOKBACK WINDOW!"
      puts '   Cause: All PageVisits are older than 30 days'
      puts '   Fix: Sync more recent browser data'
      exit 0
    end

    # Step 3: Check exclusions
    puts "\n🚫 STEP 2: Exclusion Filters"
    puts '-' * 80

    # Closed tabs
    closed_ids = TabAggregate.where.not(closed_at: nil)
      .joins('INNER JOIN page_visits ON tab_aggregates.page_visit_id = page_visits.id')
      .where(page_visits: { user_id: user.id })
      .pluck(:page_visit_id)
      .uniq
    puts "Closed tabs (excluded): #{closed_ids.count}"

    # Reading list
    saved_ids = ReadingListItem.where(user_id: user.id)
      .where.not(page_visit_id: nil)
      .pluck(:page_visit_id)
      .uniq
    puts "In reading list (excluded): #{saved_ids.count}"

    excluded_total = (closed_ids + saved_ids).uniq.count
    remaining = within_lookback - excluded_total
    puts "Remaining after exclusions: #{remaining}"

    if remaining <= 0
      puts "\n❌ ALL TABS FILTERED OUT!"
      puts '   Cause: All tabs are either closed or already in reading list'
      exit 0
    end

    # Step 4: Domain breakdown
    puts "\n🌐 STEP 3: Domain Breakdown"
    puts '-' * 80

    domain_counts = PageVisit.where(user_id: user.id)
      .where('visited_at >= ?', lookback_date)
      .where.not(id: closed_ids + saved_ids)
      .group(:domain)
      .count
      .sort_by { |_k, v| -v }

    puts 'Top domains:'
    domain_counts.first(10).each do |domain, count|
      puts "  #{domain.ljust(40)} #{count} visits"
    end

    # Step 5: Age distribution
    puts "\n📅 STEP 4: Age Distribution"
    puts '-' * 80

    visits = PageVisit.where(user_id: user.id)
      .where('visited_at >= ?', lookback_date)
      .where.not(id: closed_ids + saved_ids)

    now = Time.current
    age_groups = {
      '<1 day' => 0,
      '1-3 days' => 0,
      '3-7 days' => 0,
      '7-14 days' => 0,
      '14-30 days' => 0,
      '>30 days' => 0
    }

    visits.find_each do |visit|
      age = ((now - visit.visited_at) / 1.day).to_i
      case age
      when 0 then age_groups['<1 day'] += 1
      when 1..2 then age_groups['1-3 days'] += 1
      when 3..6 then age_groups['3-7 days'] += 1
      when 7..13 then age_groups['7-14 days'] += 1
      when 14..29 then age_groups['14-30 days'] += 1
      else age_groups['>30 days'] += 1
      end
    end

    age_groups.each do |range, count|
      puts "  #{range.ljust(15)} #{count} tabs"
    end

    # Step 6: Calculate scores for sample tabs
    puts "\n🎯 STEP 5: Hoarder Score Analysis"
    puts '-' * 80

    # Get candidates
    candidate_visits = visits.group_by(&:url)

    scores = []
    candidate_visits.each do |url, url_visits|
      # Calculate metadata
      tab_metadata = Insights::TabAgeCalculator.calculate(url_visits)
      next unless tab_metadata # Skip if calculation failed

      domain_context = Insights::DomainContextAnalyzer.analyze(
        user:,
        domain: tab_metadata[:domain],
        url:,
        tab_metadata:
      )
      hoarder_score = Insights::HoarderScorer.calculate(
        tab_metadata:,
        domain_context:
      )

      scores << {
        url:,
        domain: tab_metadata[:domain],
        age_days: tab_metadata[:tab_age_days],
        visits: tab_metadata[:visit_count],
        engagement: (tab_metadata[:engagement_rate].to_f * 100).round(1),
        score: hoarder_score[:total_score],
        is_hoarder: hoarder_score[:is_hoarder],
        excluded: hoarder_score[:should_exclude],
        exclusion_reason: hoarder_score[:exclusion_reason],
        breakdown: hoarder_score[:score_breakdown]
      }
    end

    # Sort by score descending
    scores.sort_by! { |s| -s[:score] }

    puts "\nTop 15 tabs by hoarder score:"
    puts '-' * 80
    puts "#{"Domain".ljust(25)} #{"Age".rjust(5)} #{"Visits".rjust(7)} #{"Eng%".rjust(6)} #{"Score".rjust(6)} Status"
    puts '-' * 80

    scores.first(15).each do |s|
      status = if s[:excluded]
                 "❌ #{s[:exclusion_reason]}"
               elsif s[:is_hoarder]
                 '✅ HOARDER'
               else
                 '⚪ Below threshold'
               end

      domain_short = s[:domain].to_s[0..23]
      puts "#{domain_short.ljust(25)} #{s[:age_days].to_s.rjust(5)}d #{s[:visits].to_s.rjust(7)} #{s[:engagement].to_s.rjust(6)}% #{s[:score].to_s.rjust(6)} #{status}"
    end

    # Show detailed breakdown for top candidate
    if scores.any?
      puts "\n📋 DETAILED SCORE BREAKDOWN (Top Candidate)"
      puts '-' * 80
      top = scores.first
      puts "URL: #{top[:url]}"
      puts "Domain: #{top[:domain]}"
      puts "Age: #{top[:age_days]} days"
      puts "Visits: #{top[:visits]}"
      puts "Engagement: #{top[:engagement]}%"
      puts "\nScore Breakdown:"
      top[:breakdown].each do |factor, points|
        puts "  #{factor.to_s.ljust(30)} #{points.to_s.rjust(4)} points"
      end
      puts "  #{"TOTAL".ljust(30)} #{top[:score].to_s.rjust(4)} points"
      puts "\nThreshold: 60 points"
      puts "Status: #{top[:is_hoarder] ? "✅ PASSES" : "❌ FAILS"}"
    end

    # Step 7: Summary and recommendations
    puts "\n💡 STEP 6: Summary & Recommendations"
    puts '-' * 80

    hoarders = scores.count { |s| s[:is_hoarder] && !s[:excluded] }
    excluded = scores.count { |s| s[:excluded] }
    below_threshold = scores.count { |s| !s[:is_hoarder] && !s[:excluded] }

    puts "Detected hoarders: #{hoarders}"
    puts "Excluded by rules: #{excluded}"
    puts "Below threshold (60 points): #{below_threshold}"

    if hoarders.zero?
      puts "\n❌ NO HOARDER TABS DETECTED"
      puts "\nMost likely causes:"

      if scores.any? && scores.first[:score] < 60
        puts '  1. ⚠️  Tabs not old enough (need 7+ days for 40 points)'
        puts "     → Your oldest tab is #{scores.first[:age_days]} days"
        puts '     → 3-7 day tabs only get 25 points (need 35+ more)'

        if domain_counts.keys.any? { |d| d&.include?('notion') || d&.include?('slack') || d&.include?('gmail') }
          puts "\n  2. ⚠️  Many productivity tool/email domains"
          puts '     → These get -50 point penalty if used in last 24h'
          puts '     → Even old tabs from these domains may not qualify'
        end

        avg_score = scores.pluck(:score).sum / scores.size.to_f
        puts "\n  3. 📊 Average score: #{avg_score.round(1)} points (need 60+)"
        puts '     → Consider lowering threshold to 45-50 points'
        puts '     → Or increase 3-7 day score from 25 to 35 points'
      end

      if excluded.positive?
        puts "\n  4. ⚠️  #{excluded} tabs excluded by whitelist/rules"
        top_excluded = scores.select { |s| s[:excluded] }.first(3)
        top_excluded.each do |s|
          puts "     → #{s[:domain]} (#{s[:exclusion_reason]})"
        end
      end
    else
      puts "\n✅ Detection working correctly!"
      puts "   Found #{hoarders} hoarder tabs"
    end

    puts "\n#{"=" * 80}"
  end
end
