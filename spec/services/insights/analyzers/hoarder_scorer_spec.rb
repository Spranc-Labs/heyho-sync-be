# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::Analyzers::HoarderScorer do
  describe '.calculate' do
    context 'with clear hoarder pattern (old, inactive, single visit)' do
      let(:tab_metadata) do
        {
          tab_age_days: 8.0,
          days_since_last_activity: 7.0,
          is_single_visit: true,
          visit_count: 1,
          average_engagement_rate: 0.05,
          is_likely_still_open: false,
          is_pinned: false
        }
      end

      let(:domain_context) do
        {
          domain_type: :content_site,
          should_apply_strict_rules: true,
          should_apply_lenient_rules: false
        }
      end

      it 'assigns high hoarder score' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:is_hoarder]).to be true
        expect(result[:total_score]).to be >= 80
        expect(result[:confidence_level]).to eq(:high)
      end

      it 'includes all relevant factors in breakdown' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:score_breakdown]).to include(:tab_age)
        expect(result[:score_breakdown]).to include(:inactivity)
        expect(result[:score_breakdown]).to include(:visit_pattern)
        expect(result[:score_breakdown]).to include(:engagement)
      end
    end

    context 'with pinned tab' do
      let(:tab_metadata) do
        {
          tab_age_days: 10.0,
          days_since_last_activity: 5.0,
          is_single_visit: false,
          visit_count: 10,
          average_engagement_rate: 0.1,
          is_likely_still_open: true,
          is_pinned: true
        }
      end

      let(:domain_context) do
        {
          domain_type: :general,
          should_apply_strict_rules: false,
          should_apply_lenient_rules: false
        }
      end

      it 'excludes pinned tabs from scoring' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:is_hoarder]).to be false
        expect(result[:total_score]).to eq(0)
        expect(result[:confidence_level]).to eq(:excluded)
        expect(result[:reason]).to include('Pinned tab')
      end
    end

    context 'with productivity tool with recent activity' do
      let(:tab_metadata) do
        {
          tab_age_days: 5.0,
          days_since_last_activity: 0.5,
          is_single_visit: false,
          visit_count: 20,
          average_engagement_rate: 0.05,
          is_likely_still_open: true,
          is_pinned: false
        }
      end

      let(:domain_context) do
        {
          domain_type: :productivity_tool,
          should_apply_strict_rules: false,
          should_apply_lenient_rules: true
        }
      end

      it 'excludes productivity tools with recent activity' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:is_hoarder]).to be false
        expect(result[:confidence_level]).to eq(:excluded)
        expect(result[:reason]).to include('Productivity tool')
      end
    end

    context 'with medium hoarder score (3 days old, some inactivity)' do
      let(:tab_metadata) do
        {
          tab_age_days: 3.5,
          days_since_last_activity: 1.8,
          is_single_visit: false, # Changed to false to avoid +20 bonus
          visit_count: 3,
          average_engagement_rate: 0.15,
          is_likely_still_open: false,
          is_pinned: false
        }
      end

      let(:domain_context) do
        {
          domain_type: :general,
          should_apply_strict_rules: false,
          should_apply_lenient_rules: false
        }
      end

      it 'assigns medium confidence' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:is_hoarder]).to be true
        # Score: 45 (age >= 3d) + 15 (inactive >= 1d) + 0 (not single visit) + 0 (no domain bonus) = 60
        # This gives us exactly medium confidence (60-79)
        expect(result[:total_score]).to be >= 60
        expect(result[:total_score]).to be < 80
        expect(result[:confidence_level]).to eq(:medium)
      end
    end

    context 'with active tab (recent visits, high engagement)' do
      let(:tab_metadata) do
        {
          tab_age_days: 2.0,
          days_since_last_activity: 0.2,
          is_single_visit: false,
          visit_count: 10,
          average_engagement_rate: 0.5,
          is_likely_still_open: true,
          is_pinned: false
        }
      end

      let(:domain_context) do
        {
          domain_type: :general,
          should_apply_strict_rules: false,
          should_apply_lenient_rules: false
        }
      end

      it 'does not flag as hoarder' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:is_hoarder]).to be false
        expect(result[:total_score]).to be < 60
        expect(result[:confidence_level]).to eq(:not_hoarder)
      end
    end

    context 'with score progression based on age' do
      let(:domain_context) do
        {
          domain_type: :general,
          should_apply_strict_rules: false,
          should_apply_lenient_rules: false
        }
      end

      it 'gives more points for older tabs across threshold boundaries' do
        # Test scores across the age thresholds: < 1 day (0 pts), 1-3 days (30 pts), >= 3 days (45 pts)
        tab_under_1_day = {
          tab_age_days: 0.5,
          days_since_last_activity: 0.3,
          is_single_visit: false,
          visit_count: 2,
          average_engagement_rate: 0.2,
          is_likely_still_open: false,
          is_pinned: false
        }

        tab_1_to_3_days = tab_under_1_day.merge(tab_age_days: 1.5, days_since_last_activity: 1.0)
        tab_over_3_days = tab_under_1_day.merge(tab_age_days: 4.0, days_since_last_activity: 2.5)

        score_under_1 = described_class.calculate(tab_metadata: tab_under_1_day, domain_context:)[:total_score]
        score_1_to_3 = described_class.calculate(tab_metadata: tab_1_to_3_days, domain_context:)[:total_score]
        score_over_3 = described_class.calculate(tab_metadata: tab_over_3_days, domain_context:)[:total_score]

        # Scores should increase across threshold boundaries
        expect(score_1_to_3).to be > score_under_1
        expect(score_over_3).to be > score_1_to_3
      end
    end

    context 'with score breakdown and reason generation' do
      let(:tab_metadata) do
        {
          tab_age_days: 8.0,
          days_since_last_activity: 3.0,
          is_single_visit: true,
          visit_count: 1,
          average_engagement_rate: 0.08,
          is_likely_still_open: false,
          is_pinned: false
        }
      end

      let(:domain_context) do
        {
          domain_type: :content_site,
          should_apply_strict_rules: true,
          should_apply_lenient_rules: false
        }
      end

      it 'provides detailed score breakdown' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:score_breakdown]).to be_a(Hash)
        expect(result[:score_breakdown][:tab_age]).to include(:points, :reason)
        expect(result[:score_breakdown][:inactivity]).to include(:points, :reason)
        expect(result[:score_breakdown][:visit_pattern]).to include(:points, :reason)
      end

      it 'generates human-readable reason' do
        result = described_class.calculate(tab_metadata:, domain_context:)

        expect(result[:reason]).to be_a(String)
        expect(result[:reason]).not_to be_empty
        expect(result[:reason]).to include('days')
      end
    end
  end
end
