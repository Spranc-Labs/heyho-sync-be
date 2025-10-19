# frozen_string_literal: true
# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require 'bcrypt'

# Create demo user for testing
unless User.exists?(email: 'demo@syrupy.com')
  user = User.create!(
    email: 'demo@syrupy.com',
    first_name: 'Demo',
    last_name: 'User',
    password_hash: BCrypt::Password.create('password123'),
    status: :verified,
    isVerified: true
  )
  puts "Created demo user: #{user.email} (password: password123)"
end
