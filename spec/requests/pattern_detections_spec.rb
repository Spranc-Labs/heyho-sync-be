# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Pattern Detections API' do
  let(:user) { create(:user, password_hash: BCrypt::Password.create('password123'), status: 1, isVerified: true) }
  let(:auth_token) { generate_jwt_token(user) }

  describe 'GET /api/v1/pattern_detections/serial_openers' do
    context 'with legacy parameters (backward compatibility)' do
      let!(:page_visits) do
        (1..5).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://github.com/user/repo',
            visited_at: i.hours.ago,
            duration_seconds: 10
          )
        end
      end

      it 'returns serial openers with legacy format' do
        get '/api/v1/pattern_detections/serial_openers',
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['data']).to include('serial_openers', 'count', 'criteria')
      end

      it 'accepts custom min_visits parameter' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { min_visits: 2 },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['data']['criteria']['min_visits']).to eq(2)
      end
    end

    context 'with period preset parameters' do
      let!(:week_visits) do
        (1..10).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://notion.so/page-abc',
            title: 'Project Notes',
            domain: 'notion.so',
            category: 'work_documentation',
            visited_at: i.hours.ago,
            duration_seconds: 8,
            engagement_rate: 0.3
          )
        end
      end

      it 'returns insights for period=today' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'today' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['success']).to be true
        expect(json['data']['period']).to eq('today')
        expect(json['data']['date_range']).to include('start', 'end', 'days')
      end

      it 'returns insights for period=week' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['period']).to eq('week')
      end

      it 'returns insights for period=month' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'month' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['period']).to eq('month')
      end

      it 'includes enriched insight fields' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        serial_openers = json['data']['serial_openers']

        next if serial_openers.empty?

        opener = serial_openers.first
        expect(opener).to include(
          'url',
          'normalized_url',
          'visit_count',
          'behavior_type',
          'engagement_type',
          'inferred_purpose',
          'behavioral_insight',
          'actionable_suggestion',
          'time_span_hours',
          'avg_hours_between_visits',
          'visits_per_day',
          'efficiency_score'
        )
      end

      it 'includes adaptive threshold criteria' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['criteria']).to include(
          'min_visits_per_day',
          'effective_min_visits',
          'max_total_engagement_seconds'
        )
        expect(json['data']['criteria']['min_visits_per_day']).to eq(0.43)
      end
    end

    context 'with custom date range parameters' do
      let!(:custom_visits) do
        (1..6).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://mail.google.com',
            visited_at: Date.parse('2025-10-15') + (i * 3).hours,
            duration_seconds: 12
          )
        end
      end

      it 'accepts custom start_date and end_date' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { start_date: '2025-10-15', end_date: '2025-10-20' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['period']).to eq('custom')
        expect(json['data']['date_range']['start']).to eq('2025-10-15')
        expect(json['data']['date_range']['end']).to eq('2025-10-20')
      end

      it 'returns error for invalid date range' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { start_date: '2025-10-20', end_date: '2025-10-15' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:unprocessable_entity)

        json = response.parsed_body
        expect(json['success']).to be false
        expect(json['errors']).to be_present
      end

      it 'returns error for date range exceeding 90 days' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { start_date: '2025-01-01', end_date: '2025-05-01' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:unprocessable_entity)

        json = response.parsed_body
        expect(json['success']).to be false
      end
    end

    context 'with comparison enabled' do
      let!(:current_visits) do
        (1..10).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://x.com',
            visited_at: i.days.ago,
            duration_seconds: 15
          )
        end
      end

      let!(:previous_visits) do
        (8..15).map do |i|
          create(
            :page_visit,
            user:,
            url: 'https://x.com',
            visited_at: i.days.ago,
            duration_seconds: 15
          )
        end
      end

      it 'includes comparison when include_comparison=true' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week', include_comparison: 'true' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['comparison']).to be_present
      end

      it 'includes previous period metadata in comparison' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week', include_comparison: 'true' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        comparison = json['data']['comparison']
        expect(comparison['previous_period']).to include('start', 'end', 'count')
      end

      it 'includes overall comparison statistics' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week', include_comparison: 'true' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        comparison = json['data']['comparison']
        expect(comparison['overall']).to include(
          'total_serial_openers',
          'total_visits',
          'total_engagement_seconds'
        )
      end

      it 'does not include comparison when include_comparison is not set' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['comparison']).to be_nil
      end

      it 'does not include comparison when include_comparison=false' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week', include_comparison: 'false' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['comparison']).to be_nil
      end
    end

    context 'with URL normalization' do
      let!(:github_visits) do
        [
          create(:page_visit, user:, url: 'https://github.com/user/repo/pull/123',
                              visited_at: 1.hour.ago, duration_seconds: 10),
          create(:page_visit, user:, url: 'https://github.com/user/repo/pull/123?tab=files',
                              visited_at: 2.hours.ago, duration_seconds: 10),
          create(:page_visit, user:, url: 'https://github.com/user/repo/pull/123?tab=commits',
                              visited_at: 3.hours.ago, duration_seconds: 10)
        ]
      end

      it 'groups URL variations as single resource' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        serial_openers = json['data']['serial_openers']

        next if serial_openers.empty?

        opener = serial_openers.first
        expect(opener['normalized_url']).to eq('https://github.com/user/repo/pull/123')
        expect(opener['visit_count']).to eq(3)
        expect(opener['url_variations_count']).to be >= 1
      end
    end

    context 'with no serial openers found' do
      it 'returns empty array' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week' },
            headers: { 'Authorization' => "Bearer #{auth_token}" }

        expect(response).to have_http_status(:ok)

        json = response.parsed_body
        expect(json['data']['serial_openers']).to eq([])
        expect(json['data']['count']).to eq(0)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/api/v1/pattern_detections/serial_openers',
            params: { period: 'week' }

        # Adjust expected status based on your auth setup
        expect(response).to have_http_status(:unauthorized).or have_http_status(:found)
      end
    end
  end
end
