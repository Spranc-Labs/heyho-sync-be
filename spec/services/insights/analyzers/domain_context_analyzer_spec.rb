# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::Analyzers::DomainContextAnalyzer do
  let(:user) { create(:user) }

  describe '.analyze' do
    context 'with productivity tool domains' do
      let(:tab_metadata) do
        {
          domain: 'mail.google.com',
          url: 'https://mail.google.com/mail/u/0/#inbox',
          visit_count: 10,
          days_since_last_activity: 0.5, # Active within 12 hours
          is_single_visit: false
        }
      end

      it 'classifies as productivity tool' do
        result = described_class.analyze(
          user:,
          domain: tab_metadata[:domain],
          url: tab_metadata[:url],
          tab_metadata:
        )

        expect(result[:domain_type]).to eq(:productivity_tool)
      end

      it 'applies lenient rules for recent activity' do
        result = described_class.analyze(
          user:,
          domain: tab_metadata[:domain],
          url: tab_metadata[:url],
          tab_metadata:
        )

        expect(result[:should_apply_lenient_rules]).to be true
        expect(result[:should_apply_strict_rules]).to be false
      end

      it 'does not apply lenient rules without recent activity' do
        stale_metadata = tab_metadata.merge(days_since_last_activity: 2.0)

        result = described_class.analyze(
          user:,
          domain: tab_metadata[:domain],
          url: tab_metadata[:url],
          tab_metadata: stale_metadata
        )

        expect(result[:should_apply_lenient_rules]).to be false
      end
    end

    context 'with content site domains' do
      let(:tab_metadata) do
        {
          domain: 'medium.com',
          url: 'https://medium.com/@author/some-article',
          visit_count: 1,
          days_since_last_activity: 3.0,
          is_single_visit: true
        }
      end

      it 'classifies as content site' do
        result = described_class.analyze(
          user:,
          domain: tab_metadata[:domain],
          url: tab_metadata[:url],
          tab_metadata:
        )

        expect(result[:domain_type]).to eq(:content_site)
      end

      it 'applies strict rules for single visit' do
        result = described_class.analyze(
          user:,
          domain: tab_metadata[:domain],
          url: tab_metadata[:url],
          tab_metadata:
        )

        expect(result[:should_apply_strict_rules]).to be true
        expect(result[:context_notes]).to include('classic "read later" pattern')
      end
    end

    context 'with code platform domains' do
      context 'when URL indicates active work (PR/issues)' do
        let(:tab_metadata) do
          {
            domain: 'github.com',
            url: 'https://github.com/user/repo/pull/123',
            visit_count: 5,
            days_since_last_activity: 0.2,
            is_single_visit: false
          }
        end

        it 'classifies as code platform' do
          result = described_class.analyze(
            user:,
            domain: tab_metadata[:domain],
            url: tab_metadata[:url],
            tab_metadata:
          )

          expect(result[:domain_type]).to eq(:code_platform)
        end

        it 'applies lenient rules for active work' do
          result = described_class.analyze(
            user:,
            domain: tab_metadata[:domain],
            url: tab_metadata[:url],
            tab_metadata:
          )

          expect(result[:should_apply_lenient_rules]).to be true
          expect(result[:context_notes]).to include('Active work')
        end
      end

      context 'when URL is random repository' do
        let(:tab_metadata) do
          {
            domain: 'github.com',
            url: 'https://github.com/someuser/random-repo',
            visit_count: 1,
            days_since_last_activity: 5.0,
            is_single_visit: true
          }
        end

        it 'applies strict rules for random repo' do
          result = described_class.analyze(
            user:,
            domain: tab_metadata[:domain],
            url: tab_metadata[:url],
            tab_metadata:
          )

          expect(result[:should_apply_strict_rules]).to be true
          expect(result[:context_notes]).to include('Random repository')
        end
      end
    end

    context 'with documentation sites' do
      context 'when frequently revisited' do
        let(:tab_metadata) do
          {
            domain: 'stackoverflow.com',
            url: 'https://stackoverflow.com/questions/12345',
            visit_count: 5,
            days_since_last_activity: 1.0,
            is_single_visit: false
          }
        end

        it 'classifies as documentation' do
          result = described_class.analyze(
            user:,
            domain: tab_metadata[:domain],
            url: tab_metadata[:url],
            tab_metadata:
          )

          expect(result[:domain_type]).to eq(:documentation)
        end

        it 'applies lenient rules for frequent reference' do
          result = described_class.analyze(
            user:,
            domain: tab_metadata[:domain],
            url: tab_metadata[:url],
            tab_metadata:
          )

          expect(result[:should_apply_lenient_rules]).to be true
          expect(result[:context_notes]).to include('Frequently revisited')
        end
      end

      context 'when single visit' do
        let(:tab_metadata) do
          {
            domain: 'docs.python.org',
            url: 'https://docs.python.org/3/library/asyncio.html',
            visit_count: 1,
            days_since_last_activity: 4.0,
            is_single_visit: true
          }
        end

        it 'applies strict rules' do
          result = described_class.analyze(
            user:,
            domain: tab_metadata[:domain],
            url: tab_metadata[:url],
            tab_metadata:
          )

          expect(result[:should_apply_strict_rules]).to be true
          expect(result[:context_notes]).to include('visited once')
        end
      end
    end

    context 'with general domains' do
      let(:tab_metadata) do
        {
          domain: 'example.com',
          url: 'https://example.com/page',
          visit_count: 2,
          days_since_last_activity: 2.0,
          is_single_visit: false
        }
      end

      it 'classifies as general' do
        result = described_class.analyze(
          user:,
          domain: tab_metadata[:domain],
          url: tab_metadata[:url],
          tab_metadata:
        )

        expect(result[:domain_type]).to eq(:general)
        expect(result[:should_apply_strict_rules]).to be false
        expect(result[:should_apply_lenient_rules]).to be false
      end
    end
  end
end
