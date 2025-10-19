# frozen_string_literal: true

# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "HeyHo Sync-BE Database Seeding"
puts "==============================="

if Rails.env.development?
  puts "✓ Database is ready for development"
  puts ""
  puts "To add seed data:"
  puts "  1. Create your models (User, DataSource, etc.)"
  puts "  2. Add seed data here"
  puts "  3. Run: rake db:seed or make db-seed-sync"
  puts ""
else
  puts "Seeding for #{Rails.env} environment"
end

puts "✓ Seeding completed!"
