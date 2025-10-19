# frozen_string_literal: true

FactoryBot.define do
  factory :sync_log do
    user
    synced_at { Time.current }
    status { 'completed' }
    page_visits_synced { rand(10..100) }
    tab_aggregates_synced { rand(5..50) }
    error_messages { [] }
    client_info do
      {
        user_agent: 'Mozilla/5.0',
        browser_extension_version: '1.0.0',
        browser_name: 'Firefox',
        browser_version: '119.0'
      }
    end

    trait :processing do
      status { 'processing' }
    end

    trait :failed do
      status { 'failed' }
      error_messages { ['Connection timeout', 'Invalid data'] }
    end

    trait :pending do
      status { 'pending' }
    end
  end
end
