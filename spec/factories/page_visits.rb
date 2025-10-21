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

    # Categorization fields (default: no category)
    category { nil }
    category_confidence { nil }
    category_method { nil }
    metadata { {} }

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

    # Categorization traits
    trait :work_coding do
      category { 'work_coding' }
      category_confidence { 0.85 }
      category_method { 'metadata' }
      metadata do
        {
          'schema_type' => 'SoftwareSourceCode',
          'og_site_name' => 'GitHub',
          'title' => 'Pull Request Review'
        }
      end
    end

    trait :learning_video do
      category { 'learning_video' }
      category_confidence { 0.92 }
      category_method { 'metadata' }
      metadata do
        {
          'schema_type' => 'VideoObject',
          'og_site_name' => 'YouTube',
          'title' => 'Ruby on Rails Tutorial'
        }
      end
    end

    trait :entertainment_browsing do
      category { 'entertainment_browsing' }
      category_confidence { 0.78 }
      category_method { 'metadata' }
      metadata do
        {
          'schema_type' => 'WebPage',
          'title' => 'Funny Cat Videos'
        }
      end
    end

    trait :social_media do
      category { 'social_media' }
      category_confidence { 0.95 }
      category_method { 'metadata' }
      metadata do
        {
          'og_site_name' => 'Twitter',
          'title' => 'Feed'
        }
      end
    end

    trait :unclassified do
      category { 'unclassified' }
      category_confidence { 0.4 }
      category_method { 'unclassified' }
      metadata { {} }
    end

    trait :with_rich_metadata do
      metadata do
        {
          'schema_type' => 'Article',
          'og_title' => 'Complete Guide to Ruby',
          'og_description' => 'Learn Ruby programming from scratch',
          'og_site_name' => 'RubyGuides',
          'preview' => {
            'title' => 'Complete Guide to Ruby',
            'description' => 'Learn Ruby programming from scratch',
            'image' => 'https://example.com/image.jpg',
            'site_name' => 'RubyGuides',
            'favicon' => 'https://example.com/favicon.ico'
          }
        }
      end
    end

    trait :with_large_metadata do
      metadata do
        # Create metadata that's close to but under the 50KB limit
        {
          'large_field' => 'x' * 40_000,
          'other_data' => { 'nested' => 'value' }
        }
      end
    end
  end
end
