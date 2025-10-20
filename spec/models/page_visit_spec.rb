# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PageVisit do
  # Constants
  describe 'VALID_CATEGORIES' do
    it 'includes all expected categories' do
      expected_categories = %w[
        work_coding
        work_code_review
        work_communication
        work_documentation
        learning_video
        learning_reading
        entertainment_video
        entertainment_browsing
        entertainment_short_form
        social_media
        news
        shopping
        reference
        unclassified
      ]

      expect(described_class::VALID_CATEGORIES).to match_array(expected_categories)
    end
  end

  # Associations
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:tab_aggregates).dependent(:destroy) }
    it { is_expected.to belong_to(:source_page_visit).optional }
    it { is_expected.to have_many(:child_page_visits).dependent(:nullify) }
  end

  # Validations
  describe 'validations' do
    subject(:page_visit) { build(:page_visit) }

    it { is_expected.to validate_presence_of(:url) }
    it { is_expected.to validate_presence_of(:title) }
    it { is_expected.to validate_presence_of(:visited_at) }

    describe 'category validation' do
      it { is_expected.to allow_value(nil).for(:category) }
      it { is_expected.to allow_value('work_coding').for(:category) }
      it { is_expected.to allow_value('learning_video').for(:category) }
      it { is_expected.to allow_value('entertainment_browsing').for(:category) }
      it { is_expected.to allow_value('social_media').for(:category) }
      it { is_expected.to allow_value('unclassified').for(:category) }
      it { is_expected.not_to allow_value('invalid_category').for(:category) }
    end

    describe 'category_confidence validation' do
      it { is_expected.to allow_value(nil).for(:category_confidence) }
      it { is_expected.to allow_value(0).for(:category_confidence) }
      it { is_expected.to allow_value(0.5).for(:category_confidence) }
      it { is_expected.to allow_value(1).for(:category_confidence) }
      it { is_expected.not_to allow_value(-0.1).for(:category_confidence) }
      it { is_expected.not_to allow_value(1.1).for(:category_confidence) }
    end

    describe 'category_method validation' do
      it { is_expected.to allow_value(nil).for(:category_method) }
      it { is_expected.to allow_value('metadata').for(:category_method) }
      it { is_expected.to allow_value('unclassified').for(:category_method) }
      it { is_expected.not_to allow_value('invalid_method').for(:category_method) }
    end

    describe 'metadata_size_limit' do
      it 'accepts metadata under 50KB' do
        visit = build(:page_visit, metadata: { 'small_field' => 'x' * 1000 })
        expect(visit).to be_valid
      end

      it 'rejects metadata over 50KB' do
        visit = build(:page_visit, metadata: { 'huge_field' => 'x' * 60_000 })
        expect(visit).not_to be_valid
        expect(visit.errors[:metadata]).to include(/is too large/)
      end

      it 'accepts empty metadata' do
        visit = build(:page_visit, metadata: {})
        expect(visit).to be_valid
      end

      it 'accepts nil metadata' do
        visit = build(:page_visit, metadata: nil)
        expect(visit).to be_valid
      end
    end
  end

  # Scopes
  describe 'scopes' do
    let(:user) { create(:user) }

    describe '.recent' do
      it 'orders by visited_at descending' do
        old_visit = create(:page_visit, user:, visited_at: 2.days.ago)
        new_visit = create(:page_visit, user:, visited_at: 1.day.ago)
        newest_visit = create(:page_visit, user:, visited_at: 1.hour.ago)

        expect(described_class.recent.to_a).to eq([newest_visit, new_visit, old_visit])
      end
    end

    describe '.for_user' do
      it 'returns visits for specific user' do
        user_visits = create_list(:page_visit, 3, user:)
        other_user = create(:user)
        create_list(:page_visit, 2, user: other_user)

        expect(described_class.for_user(user.id)).to match_array(user_visits)
      end
    end

    describe '.valid_data' do
      it 'includes visits with valid visited_at' do
        valid_visit = create(:page_visit, user:, visited_at: 1.hour.ago)

        expect(described_class.valid_data).to include(valid_visit)
      end

      it 'includes visits with valid url' do
        valid_visit = create(:page_visit, user:, url: 'https://example.com')

        expect(described_class.valid_data).to include(valid_visit)
      end

      it 'excludes visits with negative duration' do
        valid_visit = create(:page_visit, user:, duration_seconds: 120)
        invalid_visit = create(:page_visit, user:)
        invalid_visit.update_column(:duration_seconds, -1)

        expect(described_class.valid_data).to include(valid_visit)
        expect(described_class.valid_data).not_to include(invalid_visit)
      end

      it 'excludes visits with invalid engagement_rate' do
        valid_visit = create(:page_visit, user:, engagement_rate: 0.75)
        invalid_low = create(:page_visit, user:)
        invalid_low.update_column(:engagement_rate, -0.1)
        invalid_high = create(:page_visit, user:)
        invalid_high.update_column(:engagement_rate, 1.5)

        expect(described_class.valid_data).to include(valid_visit)
        expect(described_class.valid_data).not_to include(invalid_low)
        expect(described_class.valid_data).not_to include(invalid_high)
      end
    end

    describe 'category scopes' do
      let!(:work_coding_visit) { create(:page_visit, :work_coding, user:) }
      let!(:work_docs_visit) { create(:page_visit, user:, category: 'work_documentation') }
      let!(:learning_visit) { create(:page_visit, :learning_video, user:) }
      let!(:entertainment_visit) { create(:page_visit, :entertainment_browsing, user:) }
      let!(:social_visit) { create(:page_visit, :social_media, user:) }
      let!(:unclassified_visit) { create(:page_visit, :unclassified, user:) }
      let!(:uncategorized_visit) { create(:page_visit, user:, category: nil) }

      describe '.by_category' do
        it 'returns visits with specific category' do
          expect(described_class.by_category('work_coding')).to contain_exactly(work_coding_visit)
          expect(described_class.by_category('learning_video')).to contain_exactly(learning_visit)
        end
      end

      describe '.categorized' do
        it 'returns visits with non-nil category except unclassified' do
          expect(described_class.categorized).to contain_exactly(
            work_coding_visit,
            work_docs_visit,
            learning_visit,
            entertainment_visit,
            social_visit
          )
        end
      end

      describe '.uncategorized' do
        it 'returns visits with nil or unclassified category' do
          expect(described_class.uncategorized).to contain_exactly(
            unclassified_visit,
            uncategorized_visit
          )
        end
      end

      describe '.work_related' do
        it 'returns visits with work_* categories' do
          expect(described_class.work_related).to contain_exactly(
            work_coding_visit,
            work_docs_visit
          )
        end
      end

      describe '.learning_related' do
        it 'returns visits with learning_* categories' do
          expect(described_class.learning_related).to contain_exactly(learning_visit)
        end
      end

      describe '.entertainment_related' do
        it 'returns visits with entertainment_* categories' do
          expect(described_class.entertainment_related).to contain_exactly(entertainment_visit)
        end
      end
    end
  end

  # Metadata behavior
  describe 'metadata handling' do
    it 'stores and retrieves nested metadata' do
      metadata = {
        'schema_type' => 'Article',
        'preview' => {
          'title' => 'Test Article',
          'description' => 'Test description',
          'image' => 'https://example.com/image.jpg'
        }
      }

      visit = create(:page_visit, metadata:)
      reloaded = described_class.find(visit.id)

      expect(reloaded.metadata).to eq(metadata)
      expect(reloaded.metadata['preview']['title']).to eq('Test Article')
    end

    it 'handles empty metadata gracefully' do
      visit = create(:page_visit, metadata: {})
      expect(visit.metadata).to eq({})
    end

    it 'handles nil metadata gracefully' do
      visit = create(:page_visit, metadata: nil)
      expect(visit.metadata).to be_nil
    end
  end

  # Factory traits verification
  describe 'factory traits' do
    it 'creates work_coding visit with appropriate fields' do
      visit = build(:page_visit, :work_coding)
      expect(visit.category).to eq('work_coding')
      expect(visit.category_confidence).to be_between(0, 1)
      expect(visit.category_method).to eq('metadata')
      expect(visit.metadata).to be_present
    end

    it 'creates learning_video visit with appropriate fields' do
      visit = build(:page_visit, :learning_video)
      expect(visit.category).to eq('learning_video')
      expect(visit.category_confidence).to be_between(0, 1)
      expect(visit.category_method).to eq('metadata')
      expect(visit.metadata).to be_present
    end

    it 'creates unclassified visit with appropriate fields' do
      visit = build(:page_visit, :unclassified)
      expect(visit.category).to eq('unclassified')
      expect(visit.category_confidence).to be < 1
      expect(visit.category_method).to eq('unclassified')
    end

    it 'creates visit with rich metadata' do
      visit = build(:page_visit, :with_rich_metadata)
      expect(visit.metadata['preview']).to be_present
      expect(visit.metadata['preview']['title']).to be_present
      expect(visit.metadata['preview']['image']).to be_present
    end
  end
end
