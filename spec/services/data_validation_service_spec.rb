# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataValidationService do
  describe '.validate_page_visit' do
    it 'validates a valid page visit' do
      data = {
        'id' => 'pv_123',
        'url' => 'https://example.com/page',
        'visited_at' => Time.current.iso8601
      }

      result = described_class.validate_page_visit(data)

      expect(result.valid?).to be true
      expect(result.errors).to be_empty
    end

    context 'with missing required fields' do
      it 'returns error for missing id' do
        data = { 'url' => 'https://example.com', 'visited_at' => Time.current.iso8601 }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'id', message: 'is required but missing'))
      end

      it 'returns error for missing url' do
        data = { 'id' => 'pv_123', 'visited_at' => Time.current.iso8601 }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'url', message: 'is required but missing'))
      end

      it 'returns error for missing visited_at' do
        data = { 'id' => 'pv_123', 'url' => 'https://example.com' }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'visited_at', message: 'is required but missing'))
      end
    end

    context 'with invalid URL' do
      it 'returns error for blank URL' do
        data = { 'id' => 'pv_123', 'url' => '', 'visited_at' => Time.current.iso8601 }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'url', message: 'cannot be blank'))
      end

      it 'returns error for URL exceeding max length' do
        long_url = "https://example.com/#{"a" * 2100}"
        data = { 'id' => 'pv_123', 'url' => long_url, 'visited_at' => Time.current.iso8601 }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'url'))
      end

      it 'returns error for invalid URL scheme' do
        data = { 'id' => 'pv_123', 'url' => 'ftp://example.com', 'visited_at' => Time.current.iso8601 }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'url', message: 'must use http or https scheme'))
      end

      it 'returns error for malformed URL' do
        data = { 'id' => 'pv_123', 'url' => 'not a url', 'visited_at' => Time.current.iso8601 }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'url'))
      end

      it 'returns warning for URL missing domain' do
        data = { 'id' => 'pv_123', 'url' => 'https://', 'visited_at' => Time.current.iso8601 }

        result = described_class.validate_page_visit(data)

        expect(result.warnings).to include(hash_including(field: 'url', message: 'missing domain'))
      end
    end

    context 'with invalid timestamp' do
      it 'returns error for non-ISO8601 timestamp' do
        data = { 'id' => 'pv_123', 'url' => 'https://example.com', 'visited_at' => 'not a timestamp' }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'visited_at', message: 'is not a valid ISO8601 timestamp'))
      end
    end

    context 'with invalid duration' do
      it 'returns error for negative duration' do
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'duration_seconds' => -10
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'duration_seconds', message: 'cannot be negative'))
      end

      it 'returns error for non-numeric duration' do
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'duration_seconds' => 'not a number'
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'duration_seconds', message: 'must be a number'))
      end

      it 'returns warning for duration exceeding maximum' do
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'duration_seconds' => 100_000 # > 24 hours
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be true
        expect(result.warnings).to include(hash_including(field: 'duration_seconds'))
      end
    end

    context 'with invalid scroll depth' do
      it 'returns error for negative scroll depth' do
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'scroll_depth_percent' => -10
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'scroll_depth_percent'))
      end

      it 'returns error for scroll depth exceeding 100' do
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'scroll_depth_percent' => 150
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'scroll_depth_percent'))
      end
    end

    context 'with invalid engagement rate' do
      it 'returns error for negative engagement rate' do
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'engagement_rate' => -0.5
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'engagement_rate'))
      end

      it 'returns error for engagement rate exceeding 1.0' do
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'engagement_rate' => 1.5
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'engagement_rate'))
      end
    end

    context 'with long strings' do
      it 'returns warning for title exceeding max length' do
        long_title = 'a' * 600
        data = {
          'id' => 'pv_123',
          'url' => 'https://example.com',
          'visited_at' => Time.current.iso8601,
          'title' => long_title
        }

        result = described_class.validate_page_visit(data)

        expect(result.valid?).to be true
        expect(result.warnings).to include(hash_including(field: 'title'))
      end
    end
  end

  describe '.validate_tab_aggregate' do
    it 'validates a valid tab aggregate' do
      data = {
        'id' => 'ta_123',
        'url' => 'https://example.com',
        'closed_at' => Time.current.iso8601
      }

      result = described_class.validate_tab_aggregate(data)

      expect(result.valid?).to be true
      expect(result.errors).to be_empty
    end

    context 'with time order validation' do
      it 'returns error when closed_at is before opened_at' do
        data = {
          'id' => 'ta_123',
          'url' => 'https://example.com',
          'opened_at' => Time.current.iso8601,
          'closed_at' => 1.hour.ago.iso8601
        }

        result = described_class.validate_tab_aggregate(data)

        expect(result.valid?).to be false
        expect(result.errors).to include(hash_including(field: 'closed_at', message: 'cannot be before opened_at'))
      end

      it 'accepts valid time order' do
        data = {
          'id' => 'ta_123',
          'url' => 'https://example.com',
          'opened_at' => 1.hour.ago.iso8601,
          'closed_at' => Time.current.iso8601
        }

        result = described_class.validate_tab_aggregate(data)

        expect(result.valid?).to be true
      end
    end
  end

  describe 'Result object' do
    it 'has invalid? method' do
      result = described_class::Result.new(valid?: false, errors: [{ field: 'test', message: 'error' }], warnings: [])

      expect(result.invalid?).to be true
    end

    it 'has errors? method' do
      result = described_class::Result.new(valid?: false, errors: [{ field: 'test', message: 'error' }], warnings: [])

      expect(result.errors?).to be true
    end

    it 'has warnings? method' do
      result = described_class::Result.new(valid?: true, errors: [], warnings: [{ field: 'test', message: 'warning' }])

      expect(result.warnings?).to be true
    end
  end
end
