# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DataProcessing::DataSanitizationService do
  describe '.sanitize_page_visit' do
    it 'returns sanitized data' do
      data = {
        'id' => 'pv_123',
        'url' => 'https://example.com/page?utm_source=test',
        'title' => '  Example Page  ',
        'domain' => 'WWW.EXAMPLE.COM'
      }

      result = described_class.sanitize_page_visit(data)

      expect(result['url']).to eq('https://example.com/page')
      expect(result['title']).to eq('Example Page')
      expect(result['domain']).to eq('example.com')
    end

    context 'when sanitizing URLs' do
      it 'removes tracking parameters' do
        data = {
          'url' => 'https://example.com?utm_source=test&utm_medium=email&normal=param'
        }

        result = described_class.sanitize_page_visit(data)

        expect(result['url']).to eq('https://example.com?normal=param')
      end

      it 'removes all tracking parameters' do
        data = {
          'url' => 'https://example.com?fbclid=123&gclid=456&msclkid=789'
        }

        result = described_class.sanitize_page_visit(data)

        expect(result['url']).to eq('https://example.com')
      end

      it 'truncates overly long URLs' do
        long_url = "https://example.com/#{"a" * 3000}"
        data = { 'url' => long_url }

        result = described_class.sanitize_page_visit(data)

        expect(result['url'].length).to eq(DataValidationService::MAX_URL_LENGTH)
      end

      it 'handles malformed URLs gracefully' do
        data = { 'url' => 'not a url' }

        result = described_class.sanitize_page_visit(data)

        expect(result['url']).to eq('not a url')
      end
    end

    context 'when sanitizing text' do
      it 'strips whitespace' do
        data = { 'title' => '  Example  ' }

        result = described_class.sanitize_page_visit(data)

        expect(result['title']).to eq('Example')
      end

      it 'removes control characters' do
        data = { 'title' => "Example\x00\x01Title" }

        result = described_class.sanitize_page_visit(data)

        expect(result['title']).to eq('ExampleTitle')
      end

      it 'truncates long titles' do
        long_title = 'a' * 600
        data = { 'title' => long_title }

        result = described_class.sanitize_page_visit(data)

        expect(result['title'].length).to eq(DataValidationService::MAX_TITLE_LENGTH)
      end
    end

    context 'when sanitizing domains' do
      it 'normalizes to lowercase' do
        data = { 'domain' => 'EXAMPLE.COM' }

        result = described_class.sanitize_page_visit(data)

        expect(result['domain']).to eq('example.com')
      end

      it 'removes www prefix' do
        data = { 'domain' => 'www.example.com' }

        result = described_class.sanitize_page_visit(data)

        expect(result['domain']).to eq('example.com')
      end

      it 'strips whitespace' do
        data = { 'domain' => '  example.com  ' }

        result = described_class.sanitize_page_visit(data)

        expect(result['domain']).to eq('example.com')
      end

      it 'truncates long domains' do
        long_domain = "#{"a" * 300}.com"
        data = { 'domain' => long_domain }

        result = described_class.sanitize_page_visit(data)

        expect(result['domain'].length).to eq(DataValidationService::MAX_DOMAIN_LENGTH)
      end
    end

    context 'when sanitizing durations' do
      it 'clamps negative durations to 0' do
        data = { 'duration_seconds' => -10 }

        result = described_class.sanitize_page_visit(data)

        expect(result['duration_seconds']).to eq(0)
      end

      it 'clamps excessive durations to maximum' do
        data = { 'duration_seconds' => 100_000 }

        result = described_class.sanitize_page_visit(data)

        expect(result['duration_seconds']).to eq(DataValidationService::MAX_DURATION)
      end

      it 'converts string durations to numeric' do
        data = { 'duration_seconds' => '123.45' }

        result = described_class.sanitize_page_visit(data)

        expect(result['duration_seconds']).to eq(123.45)
      end

      it 'rounds to 2 decimal places' do
        data = { 'duration_seconds' => 123.456789 }

        result = described_class.sanitize_page_visit(data)

        expect(result['duration_seconds']).to eq(123.46)
      end
    end

    context 'when sanitizing scroll depth' do
      it 'clamps negative scroll depth to 0' do
        data = { 'scroll_depth_percent' => -10 }

        result = described_class.sanitize_page_visit(data)

        expect(result['scroll_depth_percent']).to eq(0)
      end

      it 'clamps scroll depth exceeding 100 to 100' do
        data = { 'scroll_depth_percent' => 150 }

        result = described_class.sanitize_page_visit(data)

        expect(result['scroll_depth_percent']).to eq(100)
      end

      it 'converts string scroll depth to numeric' do
        data = { 'scroll_depth_percent' => '75.5' }

        result = described_class.sanitize_page_visit(data)

        expect(result['scroll_depth_percent']).to eq(75.5)
      end

      it 'rounds to 2 decimal places' do
        data = { 'scroll_depth_percent' => 75.789 }

        result = described_class.sanitize_page_visit(data)

        expect(result['scroll_depth_percent']).to eq(75.79)
      end
    end

    context 'when sanitizing engagement rates' do
      it 'clamps negative engagement rate to 0.0' do
        data = { 'engagement_rate' => -0.5 }

        result = described_class.sanitize_page_visit(data)

        expect(result['engagement_rate']).to eq(0.0)
      end

      it 'clamps engagement rate exceeding 1.0 to 1.0' do
        data = { 'engagement_rate' => 1.5 }

        result = described_class.sanitize_page_visit(data)

        expect(result['engagement_rate']).to eq(1.0)
      end

      it 'converts string engagement rate to numeric' do
        data = { 'engagement_rate' => '0.75' }

        result = described_class.sanitize_page_visit(data)

        expect(result['engagement_rate']).to eq(0.75)
      end

      it 'rounds to 4 decimal places' do
        data = { 'engagement_rate' => 0.123456789 }

        result = described_class.sanitize_page_visit(data)

        expect(result['engagement_rate']).to eq(0.1235)
      end
    end

    context 'when values are nil' do
      it 'preserves nil values' do
        data = {
          'id' => 'pv_123',
          'url' => nil,
          'title' => nil,
          'domain' => nil
        }

        result = described_class.sanitize_page_visit(data)

        expect(result['url']).to be_nil
        expect(result['title']).to be_nil
        expect(result['domain']).to be_nil
      end
    end

    context 'when checking data immutability' do
      it 'does not modify original data' do
        original_data = {
          'url' => 'https://example.com?utm_source=test',
          'title' => '  Example  '
        }
        data_copy = original_data.dup

        described_class.sanitize_page_visit(original_data)

        expect(original_data).to eq(data_copy)
      end
    end
  end

  describe '.sanitize_tab_aggregate' do
    it 'sanitizes tab aggregate data' do
      data = {
        'id' => 'ta_123',
        'url' => 'https://example.com?utm_source=test',
        'title' => '  Example  ',
        'domain' => 'WWW.EXAMPLE.COM',
        'duration_seconds' => 100_000,
        'scroll_depth_percent' => 150
      }

      result = described_class.sanitize_tab_aggregate(data)

      expect(result['url']).to eq('https://example.com')
      expect(result['title']).to eq('Example')
      expect(result['domain']).to eq('example.com')
      expect(result['duration_seconds']).to eq(DataValidationService::MAX_DURATION)
      expect(result['scroll_depth_percent']).to eq(100)
    end
  end
end
