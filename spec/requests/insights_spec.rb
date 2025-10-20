# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Insights API' do
  let(:user) { create(:user) }
  let(:token) { Authentication::TokenService.generate_jwt_token(user) }
  let(:auth_headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/insights/daily_summary' do
    let(:today) { Time.zone.today }

    before do
      create_list(:page_visit, 3, user:, visited_at: today.beginning_of_day + 10.hours,
                                  domain: 'github.com', duration_seconds: 300, engagement_rate: 0.8)
      create_list(:page_visit, 2, user:, visited_at: today.beginning_of_day + 14.hours,
                                  domain: 'stackoverflow.com', duration_seconds: 200, engagement_rate: 0.6)
    end

    context 'when authenticated' do
      it 'returns success response' do
        get '/api/v1/insights/daily_summary', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be true
      end

      it 'returns daily summary data' do
        get '/api/v1/insights/daily_summary', headers: auth_headers

        json = response.parsed_body
        data = json['data']

        expect(data['date']).to eq(today.to_s)
        expect(data['total_sites_visited']).to eq(5)
        expect(data['unique_domains']).to eq(2)
        expect(data['total_time_seconds']).to eq(1300)
      end

      it 'includes top domain' do
        get '/api/v1/insights/daily_summary', headers: auth_headers

        json = response.parsed_body
        top_domain = json['data']['top_domain']

        expect(top_domain['domain']).to eq('github.com')
        expect(top_domain['visits']).to eq(3)
      end

      it 'includes hourly breakdown' do
        get '/api/v1/insights/daily_summary', headers: auth_headers

        json = response.parsed_body
        expect(json['data']['hourly_breakdown']).to be_an(Array)
      end

      it 'accepts date parameter' do
        yesterday = 1.day.ago.to_date
        create(:page_visit, user:, visited_at: yesterday.beginning_of_day + 10.hours)

        get '/api/v1/insights/daily_summary', params: { date: yesterday.to_s }, headers: auth_headers

        json = response.parsed_body
        expect(json['data']['date']).to eq(yesterday.to_s)
        expect(json['data']['total_sites_visited']).to eq(1)
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/insights/daily_summary'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/insights/weekly_summary' do
    let(:week_start) { Time.zone.today.beginning_of_week(:monday) }

    before do
      create_list(:page_visit, 3, user:, visited_at: week_start.beginning_of_day + 10.hours,
                                  domain: 'github.com', duration_seconds: 300)
      create_list(:page_visit, 2, user:, visited_at: week_start + 2.days + 14.hours,
                                  domain: 'stackoverflow.com', duration_seconds: 200)
    end

    context 'when authenticated' do
      it 'returns success response' do
        get '/api/v1/insights/weekly_summary', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be true
      end

      it 'returns weekly summary data' do
        get '/api/v1/insights/weekly_summary', headers: auth_headers

        json = response.parsed_body
        data = json['data']

        expect(data['start_date']).to eq(week_start.to_s)
        expect(data['total_sites_visited']).to eq(5)
        expect(data['unique_domains']).to eq(2)
      end

      it 'includes daily breakdown' do
        get '/api/v1/insights/weekly_summary', headers: auth_headers

        json = response.parsed_body
        expect(json['data']['daily_breakdown']).to be_an(Array)
      end

      it 'includes top domains' do
        get '/api/v1/insights/weekly_summary', headers: auth_headers

        json = response.parsed_body
        top_domains = json['data']['top_domains']

        expect(top_domains).to be_an(Array)
        expect(top_domains.first['domain']).to eq('github.com')
      end

      it 'accepts week parameter in ISO format' do
        get '/api/v1/insights/weekly_summary', params: { week: '2025-W42' }, headers: auth_headers

        json = response.parsed_body
        expect(json['data']['week']).to eq('2025-W42')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/insights/weekly_summary'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/insights/top_sites' do
    before do
      create_list(:page_visit, 5, user:, visited_at: 2.days.ago, domain: 'github.com',
                                  duration_seconds: 600, engagement_rate: 0.8)
      create_list(:page_visit, 3, user:, visited_at: 3.days.ago, domain: 'stackoverflow.com',
                                  duration_seconds: 400, engagement_rate: 0.6)
    end

    context 'when authenticated' do
      it 'returns success response' do
        get '/api/v1/insights/top_sites', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be true
      end

      it 'returns top sites data' do
        get '/api/v1/insights/top_sites', headers: auth_headers

        json = response.parsed_body
        sites = json['data']['sites']

        expect(sites).to be_an(Array)
        expect(sites.size).to be <= 10
        expect(sites.first['domain']).to eq('github.com')
      end

      it 'includes visit count and time' do
        get '/api/v1/insights/top_sites', headers: auth_headers

        json = response.parsed_body
        site = json['data']['sites'].first

        expect(site['visits']).to eq(5)
        expect(site['total_time_seconds']).to eq(3000)
        expect(site['avg_engagement_rate']).to be_present
      end

      it 'accepts period parameter' do
        get '/api/v1/insights/top_sites', params: { period: 'month' }, headers: auth_headers

        json = response.parsed_body
        expect(json['data']['period']).to eq('month')
      end

      it 'accepts limit parameter' do
        get '/api/v1/insights/top_sites', params: { limit: 5 }, headers: auth_headers

        json = response.parsed_body
        expect(json['data']['sites'].size).to be <= 5
      end

      it 'accepts sort_by parameter' do
        get '/api/v1/insights/top_sites', params: { sort_by: 'visits' }, headers: auth_headers

        json = response.parsed_body
        sites = json['data']['sites']

        expect(sites.first['domain']).to eq('github.com') # Most visits
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/insights/top_sites'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/insights/recent_activity' do
    before do
      # Create sessions
      5.times do |i|
        create(:page_visit, user:, visited_at: (i * 15).minutes.ago,
                            domain: 'github.com', engagement_rate: 0.8)
      end
    end

    context 'when authenticated' do
      it 'returns success response' do
        get '/api/v1/insights/recent_activity', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be true
      end

      it 'returns activity sessions' do
        get '/api/v1/insights/recent_activity', headers: auth_headers

        json = response.parsed_body
        activities = json['data']['activities']

        expect(activities).to be_an(Array)
        expect(activities).not_to be_empty
      end

      it 'includes session details' do
        get '/api/v1/insights/recent_activity', headers: auth_headers

        json = response.parsed_body
        session = json['data']['activities'].first

        expect(session['type']).to be_present
        expect(session['started_at']).to be_present
        expect(session['ended_at']).to be_present
        expect(session['domains']).to be_an(Array)
        expect(session['visit_count']).to be_present
        expect(session['avg_engagement']).to be_present
      end

      it 'accepts limit parameter' do
        get '/api/v1/insights/recent_activity', params: { limit: 3 }, headers: auth_headers

        json = response.parsed_body
        expect(json['data']['activities'].size).to be <= 3
      end

      it 'accepts since parameter' do
        get '/api/v1/insights/recent_activity',
            params: { since: 30.minutes.ago.iso8601 },
            headers: auth_headers

        json = response.parsed_body
        expect(json['data']['activities']).not_to be_empty
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/insights/recent_activity'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /api/v1/insights/productivity_hours' do
    before do
      create_list(:page_visit, 3, user:, visited_at: 2.days.ago.change(hour: 14),
                                  engagement_rate: 0.9, duration_seconds: 600)
      create_list(:page_visit, 2, user:, visited_at: 3.days.ago.change(hour: 10),
                                  engagement_rate: 0.6, duration_seconds: 400)
    end

    context 'when authenticated' do
      it 'returns success response' do
        get '/api/v1/insights/productivity_hours', headers: auth_headers

        expect(response).to have_http_status(:ok)
        json = response.parsed_body
        expect(json['success']).to be true
      end

      it 'returns productivity data' do
        get '/api/v1/insights/productivity_hours', headers: auth_headers

        json = response.parsed_body
        data = json['data']

        expect(data['most_productive_hour']).to eq(14)
        expect(data['least_productive_hour']).to eq(10)
        expect(data['hourly_stats']).to be_an(Array)
        expect(data['day_of_week_stats']).to be_an(Array)
      end

      it 'includes hourly statistics' do
        get '/api/v1/insights/productivity_hours', headers: auth_headers

        json = response.parsed_body
        hourly = json['data']['hourly_stats'].first

        expect(hourly['hour']).to be_present
        expect(hourly['avg_engagement']).to be_present
        expect(hourly['total_time_seconds']).to be_present
        expect(hourly['visit_count']).to be_present
      end

      it 'includes day of week statistics' do
        get '/api/v1/insights/productivity_hours', headers: auth_headers

        json = response.parsed_body
        day_stat = json['data']['day_of_week_stats'].first

        expect(day_stat['day']).to be_present
        expect(day_stat['avg_engagement']).to be_present
        expect(day_stat['total_time_seconds']).to be_present
      end

      it 'accepts period parameter' do
        get '/api/v1/insights/productivity_hours', params: { period: 'month' }, headers: auth_headers

        json = response.parsed_body
        expect(json['data']['period']).to eq('month')
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get '/api/v1/insights/productivity_hours'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
