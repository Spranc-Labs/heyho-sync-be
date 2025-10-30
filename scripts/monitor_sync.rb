#!/usr/bin/env ruby
# frozen_string_literal: true

# Monitor sync progress for a user
# Usage: rails runner scripts/monitor_sync.rb [user_email]

require 'io/console'

user_email = ARGV[0] || 'demo@syrupy.com'

user = User.find_by(email: user_email)
unless user
  puts "User not found: #{user_email}"
  exit 1
end

puts "Monitoring sync progress for #{user.email}"
puts '=' * 60
puts
puts 'Press Ctrl+C to stop'
puts

def format_number(num)
  num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

def format_percentage(current, total)
  return '0.0%' if total.zero?

  ((current.to_f / total) * 100).round(1)
end

last_pv_count = 0
last_ta_count = 0

loop do
  # Clear screen
  print "\033[2J\033[H"

  # Get current stats
  pv_count = PageVisit.where(user_id: user.id).count
  ta_count = TabAggregate.joins(:page_visit).where(page_visits: { user_id: user.id }).count
  sync_log_count = SyncLog.where(user_id: user.id).count
  last_sync = SyncLog.where(user_id: user.id).order(synced_at: :desc).first

  # Display header
  puts "SYNC MONITOR - #{Time.current.strftime("%H:%M:%S")}"
  puts '=' * 60

  # Display current state
  puts
  puts 'CURRENT DATABASE STATE'
  puts '-' * 60
  puts "  PageVisits:     #{format_number(pv_count)}"
  puts "  TabAggregates:  #{format_number(ta_count)}"
  puts "  Total Records:  #{format_number(pv_count + ta_count)}"
  puts "  Sync Attempts:  #{sync_log_count}"

  # Display last sync
  if last_sync
    puts
    puts 'LAST SYNC ATTEMPT'
    puts '-' * 60
    puts "  Time:           #{last_sync.synced_at.strftime("%H:%M:%S")}"
    puts "  Status:         #{last_sync.status.upcase}"
    puts "  PageVisits:     +#{last_sync.page_visits_synced}"
    puts "  TabAggregates:  +#{last_sync.tab_aggregates_synced}"
    puts "  Rejected:       #{last_sync.rejected_records_count}"
  end

  # Display changes since last check
  pv_delta = pv_count - last_pv_count
  ta_delta = ta_count - last_ta_count

  if pv_delta.positive? || ta_delta.positive?
    puts
    puts 'CHANGES SINCE LAST CHECK'
    puts '-' * 60
    puts "  PageVisits:     +#{pv_delta}" if pv_delta.positive?
    puts "  TabAggregates:  +#{ta_delta}" if ta_delta.positive?
  end

  # Display what user reported
  puts
  puts 'BROWSER EXTENSION REPORTS'
  puts '-' * 60
  puts '  PageVisits:     1,876 (from your screenshot)'
  puts '  TabAggregates:  350 (from your screenshot)'
  puts
  puts 'SYNC PROGRESS'
  puts '-' * 60
  puts "  PageVisits:     #{format_percentage(pv_count, 1876)}% (#{pv_count}/1,876)"
  puts "  TabAggregates:  #{format_percentage(ta_count, 350)}% (#{ta_count}/350)"

  # Estimate time to completion
  if pv_delta.positive? || ta_delta.positive?
    records_per_check = pv_delta + ta_delta
    remaining = (1876 - pv_count) + (350 - ta_count)
    if records_per_check.positive?
      checks_remaining = (remaining.to_f / records_per_check).ceil
      seconds_remaining = checks_remaining * 5
      puts
      puts "  Estimated time: #{seconds_remaining / 60} minutes (at current rate)"
    end
  end

  # Update counters
  last_pv_count = pv_count
  last_ta_count = ta_count

  # Wait 5 seconds
  sleep 5
end
