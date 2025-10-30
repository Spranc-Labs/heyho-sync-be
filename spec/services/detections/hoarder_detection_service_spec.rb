# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Detections::HoarderDetectionService do
  let(:user) { create(:user) }

  describe '.call with new age-based detection' do
    context 'with clear hoarder tabs' do
      before do
        # Hoarder tab 1: Old article, single visit, no recent activity
        create(:page_visit,
               user:,
               url: 'https://medium.com/@author/old-article',
               domain: 'medium.com',
               title: 'Old Article I Never Read',
               visited_at: 8.days.ago,
               duration_seconds: 1800,
               active_duration_seconds: 100,
               engagement_rate: 0.05)

        # Hoarder tab 2: Documentation, single visit, abandoned
        create(:page_visit,
               user:,
               url: 'https://docs.python.org/3/library/asyncio.html',
               domain: 'docs.python.org',
               title: 'asyncio — Asynchronous I/O',
               visited_at: 5.days.ago,
               duration_seconds: 900,
               active_duration_seconds: 50,
               engagement_rate: 0.06)
      end

      it 'detects hoarder tabs' do
        result = described_class.call(user, lookback_days: 30)

        expect(result).not_to be_empty
        expect(result.first).to include(:hoarder_score, :confidence_level, :reason)
      end

      it 'sorts tabs by hoarder score' do
        result = described_class.call(user, lookback_days: 30)

        scores = result.pluck(:hoarder_score)
        expect(scores).to eq(scores.sort.reverse)
      end

      it 'provides comprehensive tab information' do
        result = described_class.call(user, lookback_days: 30)
        tab = result.first

        expect(tab).to include(
          :url,
          :title,
          :domain,
          :tab_age_days,
          :days_since_last_activity,
          :visit_count,
          :hoarder_score,
          :confidence_level,
          :reason,
          :score_breakdown,
          :suggested_action
        )
      end
    end

    context 'with pinned tabs' do
      before do
        # Pinned Gmail tab (should be excluded)
        create(:page_visit,
               user:,
               url: 'https://mail.google.com/mail/u/0/#inbox',
               domain: 'mail.google.com',
               title: 'Gmail',
               visited_at: 10.days.ago,
               duration_seconds: 86_400, # 24 hours (always open)
               engagement_rate: 0.02,
               metadata: { pinned: true })
      end

      it 'excludes pinned tabs from results' do
        result = described_class.call(user, lookback_days: 30)

        expect(result).to be_empty
      end
    end

    context 'with productivity tools with recent activity' do
      before do
        # Gmail with recent activity
        create(:page_visit,
               user:,
               url: 'https://mail.google.com/mail/u/0/#inbox',
               domain: 'mail.google.com',
               title: 'Gmail',
               visited_at: 5.days.ago,
               duration_seconds: 3600,
               engagement_rate: 0.1)

        create(:page_visit,
               user:,
               url: 'https://mail.google.com/mail/u/0/#inbox',
               domain: 'mail.google.com',
               title: 'Gmail',
               visited_at: 4.hours.ago,
               duration_seconds: 1800,
               engagement_rate: 0.15)
      end

      it 'excludes productivity tools with recent activity' do
        result = described_class.call(user, lookback_days: 30)

        expect(result).to be_empty
      end
    end

    context 'with GitHub PRs (active work)' do
      before do
        # GitHub PR with multiple visits (active work)
        create(:page_visit,
               user:,
               url: 'https://github.com/user/repo/pull/123',
               domain: 'github.com',
               title: 'Fix bug in authentication',
               visited_at: 3.days.ago,
               duration_seconds: 2400,
               engagement_rate: 0.08)

        create(:page_visit,
               user:,
               url: 'https://github.com/user/repo/pull/123',
               domain: 'github.com',
               title: 'Fix bug in authentication',
               visited_at: 1.day.ago,
               duration_seconds: 1800,
               engagement_rate: 0.12)
      end

      it 'excludes active work from hoarder detection' do
        result = described_class.call(user, lookback_days: 30)

        expect(result).to be_empty
      end
    end

    context 'with tabs already in reading list' do
      let(:page_visit) do
        create(:page_visit,
               user:,
               url: 'https://example.com/article',
               domain: 'example.com',
               title: 'Already Saved Article',
               visited_at: 10.days.ago,
               duration_seconds: 1800,
               engagement_rate: 0.05)
      end

      before do
        create(:reading_list_item,
               user:,
               page_visit_id: page_visit.id,
               url: page_visit.url,
               title: page_visit.title,
               domain: page_visit.domain)
      end

      it 'excludes tabs already in reading list' do
        result = described_class.call(user, lookback_days: 30)

        expect(result).to be_empty
      end
    end

    context 'with closed tabs (TabAggregate data)' do
      let(:open_tab_visit) do
        create(:page_visit,
               user:,
               url: 'https://example.com/open-tab',
               domain: 'example.com',
               title: 'Still Open Tab',
               visited_at: 7.days.ago,
               duration_seconds: 1800,
               engagement_rate: 0.05)
      end

      let(:closed_tab_visit) do
        create(:page_visit,
               user:,
               url: 'https://example.com/closed-tab',
               domain: 'example.com',
               title: 'Closed Tab',
               visited_at: 7.days.ago,
               duration_seconds: 1800,
               engagement_rate: 0.05)
      end

      before do
        open_tab_visit
        closed_tab_visit

        # Add TabAggregate showing tab was closed 5 days ago
        create(:tab_aggregate,
               page_visit: closed_tab_visit,
               closed_at: 5.days.ago,
               total_time_seconds: 166,
               active_time_seconds: 60,
               scroll_depth_percent: 25.0)
      end

      it 'excludes tabs that have been closed (have TabAggregate with closed_at)' do
        result = described_class.call(user, lookback_days: 30)

        # Should only return the open tab, not the closed one
        expect(result.size).to eq(1)
        expect(result.first[:url]).to eq('https://example.com/open-tab')
        expect(result.first[:url]).not_to eq('https://example.com/closed-tab')
      end

      it 'does not flag closed tabs as hoarders even if they meet hoarder criteria' do
        result = described_class.call(user, lookback_days: 30)
        closed_tabs = result.select { |tab| tab[:url] == 'https://example.com/closed-tab' }

        expect(closed_tabs).to be_empty
      end
    end

    context 'with mix of hoarder and active tabs' do
      before do
        # Hoarder: Old article, single visit
        create(:page_visit,
               user:,
               url: 'https://blog.example.com/old-post',
               domain: 'blog.example.com',
               title: 'Old Blog Post',
               visited_at: 7.days.ago,
               duration_seconds: 1200,
               engagement_rate: 0.05)

        # Active: Recent article with multiple visits
        create(:page_visit,
               user:,
               url: 'https://blog.example.com/active-post',
               domain: 'blog.example.com',
               title: 'Active Blog Post',
               visited_at: 2.days.ago,
               duration_seconds: 900,
               engagement_rate: 0.3)

        create(:page_visit,
               user:,
               url: 'https://blog.example.com/active-post',
               domain: 'blog.example.com',
               title: 'Active Blog Post',
               visited_at: 4.hours.ago,
               duration_seconds: 600,
               engagement_rate: 0.4)
      end

      it 'only returns hoarder tabs' do
        result = described_class.call(user, lookback_days: 30)

        expect(result.size).to eq(1)
        expect(result.first[:url]).to eq('https://blog.example.com/old-post')
      end
    end

    context 'with lookback_days parameter' do
      before do
        # Tab within 7 days
        create(:page_visit,
               user:,
               url: 'https://example.com/recent',
               domain: 'example.com',
               title: 'Recent Article',
               visited_at: 5.days.ago,
               duration_seconds: 1800,
               engagement_rate: 0.05)

        # Tab older than 7 days
        create(:page_visit,
               user:,
               url: 'https://example.com/old',
               domain: 'example.com',
               title: 'Old Article',
               visited_at: 10.days.ago,
               duration_seconds: 1800,
               engagement_rate: 0.05)
      end

      it 'respects lookback_days limit' do
        result = described_class.call(user, lookback_days: 7)

        urls = result.pluck(:url)
        expect(urls).to include('https://example.com/recent')
        expect(urls).not_to include('https://example.com/old')
      end
    end
  end

  describe '.legacy_detection (backwards compatibility)' do
    before do
      # Tab matching old criteria: duration >= 30min, engagement <= 20%
      create(:page_visit,
             user:,
             url: 'https://example.com/old-criteria',
             domain: 'example.com',
             title: 'Old Criteria Tab',
             visited_at: 1.hour.ago,
             duration_seconds: 2000,
             engagement_rate: 0.15)
    end

    it 'still works with old parameters' do
      result = described_class.call(user, min_open_time: 30.minutes, max_engagement: 0.2)

      expect(result).not_to be_empty
      expect(result.first).to include(:url, :title, :domain, :suggested_action)
    end

    it 'logs deprecation warning' do
      expect(Rails.logger).to receive(:warn).with(/deprecated/)

      described_class.call(user, min_open_time: 30.minutes)
    end
  end

  describe 'empty results' do
    context 'when user has no page visits' do
      it 'returns empty array' do
        result = described_class.call(user, lookback_days: 30)

        expect(result).to eq([])
      end
    end

    context 'when all tabs are active/recent' do
      before do
        create(:page_visit,
               user:,
               url: 'https://example.com/active',
               domain: 'example.com',
               title: 'Active Tab',
               visited_at: 1.hour.ago,
               duration_seconds: 600,
               engagement_rate: 0.5)
      end

      it 'returns empty array' do
        result = described_class.call(user, lookback_days: 30)

        expect(result).to eq([])
      end
    end
  end
end
