# frozen_string_literal: true

FactoryBot.define do
  factory :tab_aggregate do
    id { SecureRandom.uuid }
    page_visit

    closed_at { 1.hour.ago }
    total_time_seconds { 300 } # 5 minutes
    active_time_seconds { 150 } # 2.5 minutes
    scroll_depth_percent { 50.0 }

    trait :recently_closed do
      closed_at { 10.minutes.ago }
      total_time_seconds { 600 }
      active_time_seconds { 300 }
    end

    trait :long_duration do
      total_time_seconds { 3600 } # 1 hour
      active_time_seconds { 1800 } # 30 minutes
    end

    trait :low_engagement do
      total_time_seconds { 1800 }
      active_time_seconds { 60 } # Only 1 minute active
      scroll_depth_percent { 5.0 }
    end
  end
end
