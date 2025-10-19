# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    first_name { 'Test' }
    last_name { 'User' }
    password_hash { BCrypt::Password.create('password123') }
    status { :verified }
    isVerified { true }

    trait :unverified do
      status { :unverified }
      isVerified { false }
    end

    trait :closed do
      status { :closed }
      isVerified { false }
    end
  end
end
