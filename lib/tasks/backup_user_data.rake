# frozen_string_literal: true

namespace :backup do
  desc 'Backup PageVisits and TabAggregates data for a specific user'
  task user_data: :environment do
    email = ENV.fetch('EMAIL', nil)
    backup_dir = ENV['BACKUP_DIR'] || 'backups/user_data'

    unless email
      puts '❌ Error: EMAIL environment variable required'
      puts 'Usage: EMAIL=user@example.com bundle exec rake backup:user_data'
      puts 'Optional: BACKUP_DIR=custom/path bundle exec rake backup:user_data'
      exit 1
    end

    user = User.find_by(email:)
    unless user
      puts "❌ User not found: #{email}"
      exit 1
    end

    # Create backup directory
    FileUtils.mkdir_p(backup_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    user_slug = email.gsub('@', '_at_').tr('.', '_')
    backup_file = "#{backup_dir}/#{user_slug}_#{timestamp}.json"

    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts '📦 USER DATA BACKUP'
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts "User: #{email} (ID: #{user.id})"
    puts "Timestamp: #{Time.current}"
    puts "Backup file: #{backup_file}"
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts ''

    # Fetch data
    puts '📊 Fetching data...'
    page_visits = PageVisit.where(user_id: user.id).order(:visited_at)

    # Get TabAggregates for these visits
    visit_ids = page_visits.pluck(:id)
    tab_aggregates = TabAggregate.where(page_visit_id: visit_ids)

    puts "  PageVisits: #{page_visits.count}"
    puts "  TabAggregates: #{tab_aggregates.count}"
    puts ''

    # Build backup data structure
    backup_data = {
      metadata: {
        backup_timestamp: Time.current.iso8601,
        user_email: email,
        user_id: user.id,
        page_visits_count: page_visits.count,
        tab_aggregates_count: tab_aggregates.count,
        version: '1.0'
      },
      page_visits: page_visits.map do |pv|
        {
          id: pv.id,
          user_id: pv.user_id,
          url: pv.url,
          title: pv.title,
          domain: pv.domain,
          visited_at: pv.visited_at.iso8601,
          duration_seconds: pv.duration_seconds,
          active_duration_seconds: pv.active_duration_seconds,
          engagement_rate: pv.engagement_rate,
          category: pv.category,
          metadata: pv.metadata,
          created_at: pv.created_at.iso8601,
          updated_at: pv.updated_at.iso8601
        }
      end,
      tab_aggregates: tab_aggregates.map do |ta|
        {
          id: ta.id,
          page_visit_id: ta.page_visit_id,
          closed_at: ta.closed_at&.iso8601,
          total_time_seconds: ta.total_time_seconds,
          active_time_seconds: ta.active_time_seconds,
          scroll_depth_percent: ta.scroll_depth_percent,
          domain_durations: ta.domain_durations,
          page_count: ta.page_count,
          current_url: ta.current_url,
          current_domain: ta.current_domain,
          statistics: ta.statistics,
          created_at: ta.created_at.iso8601,
          updated_at: ta.updated_at.iso8601
        }
      end
    }

    # Write to file
    puts '💾 Writing backup file...'
    File.write(backup_file, JSON.pretty_generate(backup_data))

    file_size = File.size(backup_file)
    file_size_mb = (file_size / 1024.0 / 1024.0).round(2)

    puts '✅ Backup complete!'
    puts ''
    puts "📁 Backup saved: #{backup_file}"
    puts "📏 File size: #{file_size_mb} MB"
    puts ''

    # Show recent backups
    puts '📋 Recent backups for this user:'
    backups = Dir.glob("#{backup_dir}/#{user_slug}_*.json").last(5).reverse
    if backups.any?
      backups.each do |backup|
        size = (File.size(backup) / 1024.0 / 1024.0).round(2)
        mtime = File.mtime(backup)
        puts "  #{File.basename(backup)} - #{size} MB - #{mtime.strftime("%Y-%m-%d %H:%M:%S")}"
      end
    else
      puts '  (no previous backups)'
    end

    puts ''
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  end

  desc 'Restore PageVisits and TabAggregates data from backup'
  task restore_user_data: :environment do
    backup_file = ENV.fetch('BACKUP_FILE', nil)

    unless backup_file
      puts '❌ Error: BACKUP_FILE environment variable required'
      puts 'Usage: BACKUP_FILE=backups/user_data/demo_at_syrupy_com_20251029_060000.json bundle exec rake backup:restore_user_data'
      exit 1
    end

    unless File.exist?(backup_file)
      puts "❌ Backup file not found: #{backup_file}"
      exit 1
    end

    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts '📥 USER DATA RESTORE'
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts "Backup file: #{backup_file}"
    puts "File size: #{(File.size(backup_file) / 1024.0 / 1024.0).round(2)} MB"
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts ''

    # Load backup data
    puts '📖 Loading backup data...'
    backup_data = JSON.parse(File.read(backup_file))

    metadata = backup_data['metadata']
    puts "  Backup from: #{metadata["backup_timestamp"]}"
    puts "  User: #{metadata["user_email"]}"
    puts "  PageVisits: #{metadata["page_visits_count"]}"
    puts "  TabAggregates: #{metadata["tab_aggregates_count"]}"
    puts ''

    # Find user
    user = User.find_by(email: metadata['user_email'])
    unless user
      puts "❌ User not found: #{metadata["user_email"]}"
      puts '   Please create the user first'
      exit 1
    end

    # Confirmation prompt
    puts '⚠️  WARNING: This will DELETE existing data and restore from backup'
    print 'Continue? (yes/no): '
    confirmation = $stdin.gets.chomp
    unless confirmation.casecmp('yes').zero?
      puts '❌ Restore cancelled'
      exit 0
    end

    puts ''
    puts '🗑️  Deleting existing data...'

    # Delete existing data for this user
    deleted_page_visits = PageVisit.where(user_id: user.id).delete_all
    puts "  Deleted #{deleted_page_visits} PageVisits"

    puts ''
    puts '📥 Restoring data...'

    # Restore PageVisits
    restored_visits = 0
    backup_data['page_visits'].each do |pv_data|
      PageVisit.create!(
        id: pv_data['id'],
        user_id: user.id,
        url: pv_data['url'],
        title: pv_data['title'],
        domain: pv_data['domain'],
        visited_at: Time.zone.parse(pv_data['visited_at']),
        duration_seconds: pv_data['duration_seconds'],
        active_duration_seconds: pv_data['active_duration_seconds'],
        engagement_rate: pv_data['engagement_rate'],
        category: pv_data['category'],
        metadata: pv_data['metadata'] || {},
        created_at: Time.zone.parse(pv_data['created_at']),
        updated_at: Time.zone.parse(pv_data['updated_at'])
      )
      restored_visits += 1
    end
    puts "  ✅ Restored #{restored_visits} PageVisits"

    # Restore TabAggregates
    restored_aggregates = 0
    backup_data['tab_aggregates'].each do |ta_data|
      TabAggregate.create!(
        id: ta_data['id'],
        page_visit_id: ta_data['page_visit_id'],
        closed_at: ta_data['closed_at'] ? Time.zone.parse(ta_data['closed_at']) : nil,
        total_time_seconds: ta_data['total_time_seconds'],
        active_time_seconds: ta_data['active_time_seconds'],
        scroll_depth_percent: ta_data['scroll_depth_percent'],
        domain_durations: ta_data['domain_durations'] || {},
        page_count: ta_data['page_count'],
        current_url: ta_data['current_url'],
        current_domain: ta_data['current_domain'],
        statistics: ta_data['statistics'] || {},
        created_at: Time.zone.parse(ta_data['created_at']),
        updated_at: Time.zone.parse(ta_data['updated_at'])
      )
      restored_aggregates += 1
    end
    puts "  ✅ Restored #{restored_aggregates} TabAggregates"

    puts ''
    puts '✅ Restore complete!'
    puts ''
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  end

  desc 'List available backups for a user'
  task list: :environment do
    email = ENV.fetch('EMAIL', nil)
    backup_dir = ENV['BACKUP_DIR'] || 'backups/user_data'

    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts '📋 AVAILABLE BACKUPS'
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'

    if email
      user_slug = email.gsub('@', '_at_').tr('.', '_')
      pattern = "#{backup_dir}/#{user_slug}_*.json"
      puts "User: #{email}"
    else
      pattern = "#{backup_dir}/*.json"
      puts 'All users'
    end

    puts "Directory: #{backup_dir}"
    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
    puts ''

    backups = Dir.glob(pattern).reverse

    if backups.empty?
      puts '  (no backups found)'
      puts ''
      puts 'To create a backup: EMAIL=user@example.com bundle exec rake backup:user_data'
    else
      backups.each do |backup|
        size = (File.size(backup) / 1024.0 / 1024.0).round(2)
        mtime = File.mtime(backup)

        # Try to read metadata
        begin
          data = JSON.parse(File.read(backup))
          metadata = data['metadata']
          puts File.basename(backup)
          puts "  Size: #{size} MB"
          puts "  Date: #{mtime.strftime("%Y-%m-%d %H:%M:%S")}"
          puts "  User: #{metadata["user_email"]}"
          puts "  PageVisits: #{metadata["page_visits_count"]}"
          puts "  TabAggregates: #{metadata["tab_aggregates_count"]}"
          puts ''
        rescue StandardError => e
          puts "#{File.basename(backup)} - #{size} MB - #{mtime.strftime("%Y-%m-%d %H:%M:%S")} (error reading: #{e.message})"
          puts ''
        end
      end

      puts "Total backups: #{backups.count}"
    end

    puts '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
  end
end
