# frozen_string_literal: true

FactoryBot.define do
  factory :reading_list_item do
    user
    page_visit factory: %i[page_visit], optional: true

    sequence(:url) { |n| "https://example.com/article-#{n}" }
    title { 'Test Article' }
    domain { 'example.com' }
    added_at { Time.current }
    added_from { 'manual_save' }
    status { 'unread' }
    estimated_read_time { 300 } # 5 minutes in seconds
    notes { nil }
    tags { [] }
    scheduled_for { nil }
    completed_at { nil }
    dismissed_at { nil }

    trait :reading do
      status { 'reading' }
    end

    trait :completed do
      status { 'completed' }
      completed_at { Time.current }
    end

    trait :dismissed do
      status { 'dismissed' }
      dismissed_at { Time.current }
    end

    trait :scheduled do
      scheduled_for { 1.hour.from_now }
    end

    trait :from_hoarder_detection do
      added_from { 'hoarder_detection' }
    end

    trait :from_api do
      added_from { 'api_import' }
    end
  end
end
