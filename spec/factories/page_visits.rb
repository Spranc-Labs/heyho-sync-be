# frozen_string_literal: true

FactoryBot.define do
  factory :page_visit do
    id { SecureRandom.uuid }
    user
    sequence(:url) { |n| "https://example#{n}.com/page" }
    sequence(:title) { |n| "Page Title #{n}" }
    visited_at { Time.current }
    domain { url.present? ? URI.parse(url).host : nil }
    duration_seconds { 120 }
    active_duration_seconds { 90 }
    engagement_rate { 0.75 }
    tab_id { rand(1..1000) }

    trait :with_long_duration do
      duration_seconds { 3600 }
      active_duration_seconds { 2400 }
      engagement_rate { 0.9 }
    end

    trait :with_short_duration do
      duration_seconds { 30 }
      active_duration_seconds { 20 }
      engagement_rate { 0.3 }
    end

    trait :invalid_data do
      duration_seconds { -1 }
      engagement_rate { 1.5 }
    end
  end
end
