# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::RecentActivityService do
  describe '.call' do
    let(:user) { create(:user) }
    let(:now) { Time.current }

    context 'with visits forming multiple sessions' do
      before do
        # Session 1: Research session (>30min, >10 visits)
        base_time = 2.hours.ago
        15.times do |i|
          create(:page_visit, user:, visited_at: base_time + (i * 3).minutes,
                              domain: 'github.com', engagement_rate: 0.8)
        end

        # Session 2: Browsing session (>10min = 600s)
        base_time = 1.hour.ago
        7.times do |i|
          create(:page_visit, user:, visited_at: base_time + (i * 2).minutes,
                              domain: 'stackoverflow.com', engagement_rate: 0.6)
        end

        # Session 3: Quick search (>5 visits)
        base_time = 30.minutes.ago
        6.times do |i|
          create(:page_visit, user:, visited_at: base_time + (i * 1).minutes,
                              domain: 'google.com', engagement_rate: 0.4)
        end

        # Session 4: Brief visit
        create_list(:page_visit, 2, user:, visited_at: 10.minutes.ago,
                                    domain: 'twitter.com', engagement_rate: 0.5)
      end

      it 'returns success result' do
        result = described_class.call(user:)

        expect(result.success?).to be true
      end

      it 'groups visits into sessions' do
        result = described_class.call(user:)

        expect(result.data[:activities]).to be_an(Array)
        expect(result.data[:activities].size).to be >= 4
      end

      it 'classifies research sessions correctly' do
        result = described_class.call(user:)

        research = result.data[:activities].find { |a| a[:type] == 'research_session' }
        expect(research).to be_present
        expect(research[:visit_count]).to be >= 10
        expect(research[:duration_seconds]).to be >= 1800
      end

      it 'classifies browsing sessions correctly' do
        result = described_class.call(user:)

        browsing = result.data[:activities].find { |a| a[:type] == 'browsing_session' }
        expect(browsing).to be_present
        expect(browsing[:duration_seconds]).to be >= 600
      end

      it 'classifies quick searches correctly' do
        result = described_class.call(user:)

        quick_search = result.data[:activities].find { |a| a[:type] == 'quick_search' }
        expect(quick_search).to be_present
        expect(quick_search[:visit_count]).to be >= 5
      end

      it 'classifies brief visits correctly' do
        result = described_class.call(user:)

        brief = result.data[:activities].find { |a| a[:type] == 'brief_visit' }
        expect(brief).to be_present
      end

      it 'includes domains for each session' do
        result = described_class.call(user:)

        session = result.data[:activities].first
        expect(session[:domains]).to be_an(Array)
        expect(session[:domains]).not_to be_empty
      end

      it 'includes start and end times' do
        result = described_class.call(user:)

        session = result.data[:activities].first
        expect(session[:started_at]).to be_present
        expect(session[:ended_at]).to be_present
      end

      it 'includes visit count for each session' do
        result = described_class.call(user:)

        session = result.data[:activities].first
        expect(session[:visit_count]).to be > 0
      end

      it 'calculates average engagement' do
        result = described_class.call(user:)

        session = result.data[:activities].first
        expect(session[:avg_engagement]).to be_a(Float)
        expect(session[:avg_engagement]).to be_between(0.0, 1.0)
      end
    end

    context 'with visits separated by large time gaps' do
      before do
        # Session 1
        create_list(:page_visit, 3, user:, visited_at: 2.hours.ago, domain: 'site1.com')

        # Gap > 10 minutes -> new session
        # Session 2
        create_list(:page_visit, 2, user:, visited_at: 1.hour.ago, domain: 'site2.com')
      end

      it 'creates separate sessions for large gaps' do
        result = described_class.call(user:)

        expect(result.data[:activities].size).to eq(2)
      end
    end

    context 'with limit parameter' do
      before do
        # Create 25 sessions (each with 1 visit, separated by >10 min)
        25.times do |i|
          create(:page_visit, user:, visited_at: (i * 15).minutes.ago)
        end
      end

      it 'respects the limit parameter' do
        result = described_class.call(user:, limit: 10)

        expect(result.data[:activities].size).to eq(10)
      end

      it 'clamps limit to maximum of 100' do
        result = described_class.call(user:, limit: 200)

        expect(result.data[:activities].size).to be <= 100
      end

      it 'uses default limit of 20' do
        result = described_class.call(user:)

        expect(result.data[:activities].size).to be <= 20
      end
    end

    context 'with since parameter' do
      before do
        create(:page_visit, user:, visited_at: 30.minutes.ago, domain: 'recent.com')
        create(:page_visit, user:, visited_at: 25.hours.ago, domain: 'old.com')
      end

      it 'filters visits by since parameter' do
        result = described_class.call(user:, since: 1.hour.ago.iso8601)

        activities = result.data[:activities]
        domains = activities.flat_map { |a| a[:domains] }
        expect(domains).to include('recent.com')
        expect(domains).not_to include('old.com')
      end

      it 'defaults to 24 hours ago when since is not provided' do
        result = described_class.call(user:)

        activities = result.data[:activities]
        domains = activities.flat_map { |a| a[:domains] }
        expect(domains).to include('recent.com')
        expect(domains).not_to include('old.com')
      end
    end

    context 'when visits have nil engagement rates' do
      before do
        create_list(:page_visit, 3, user:, visited_at: 1.hour.ago, engagement_rate: nil)
      end

      it 'handles nil engagement rates gracefully' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        session = result.data[:activities].first
        expect(session[:avg_engagement]).to eq(0.0)
      end
    end

    context 'when no visits exist' do
      it 'returns empty activities array' do
        result = described_class.call(user:)

        expect(result.success?).to be true
        expect(result.data[:activities]).to eq([])
      end
    end

    context 'when service encounters an error' do
      before do
        allow_any_instance_of(described_class).to receive(:fetch_visits).and_raise(StandardError, 'Database error')
      end

      it 'returns failure result' do
        result = described_class.call(user:)

        expect(result.failure?).to be true
        expect(result.message).to eq('Failed to generate recent activity')
        expect(result.errors).to include('Database error')
      end
    end
  end
end
