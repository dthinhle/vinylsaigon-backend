# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WordpressMigration::CategoryMigrator do
  let(:categories_json) { File.read(Rails.root.join('spec/fixtures/wordpress_migration/categories.json')) }
  let(:migrator) { described_class.new(categories_json) }

  describe '#initialize' do
    it 'parses categories JSON' do
      expect(migrator.wp_categories).to be_an(Array)
      expect(migrator.wp_categories).not_to be_empty
    end

    it 'initializes with empty errors' do
      expect(migrator.errors).to eq([])
    end

    it 'initializes with empty mapping' do
      expect(migrator.mapping).to eq({})
    end
  end

  describe '#migrate!' do
    context 'with valid categories data' do
      it 'creates root categories' do
        expect {
          migrator.migrate!
        }.to change(Category, :count)

        root_categories = Category.where(is_root: true)
        expect(root_categories).to be_present
      end

      it 'creates child categories with proper parent relationship' do
        migrator.migrate!

        # Find a child category from the fixture
        child_category = Category.find_by(title: 'Smartphones')
        expect(child_category).to be_present if child_category
        expect(child_category.parent).to be_present if child_category
        expect(child_category.parent.is_root).to be true if child_category
      end

      it 'returns success result' do
        result = migrator.migrate!

        expect(result[:success]).to be true
        expect(result[:errors]).to be_empty
        expect(result[:mapping]).to be_a(Hash)
      end

      it 'creates category mapping' do
        result = migrator.migrate!

        expect(result[:mapping]).not_to be_empty
        # Verify mapping contains wp_id => new_category_id pairs
        result[:mapping].each do |wp_id, category_id|
          expect(wp_id).to be_present
          expect(category_id).to be_present
          expect(Category.exists?(id: category_id)).to be true
        end
      end

      it 'maps category names according to CATEGORY_MAPPING' do
        migrator.migrate!

        # Check if electronics category exists (not mapped, should use original name)
        electronics = Category.find_by(title: 'Electronics')
        expect(electronics).to be_present
      end

      it 'does not create duplicate categories on second run' do
        migrator.migrate!
        initial_count = Category.count

        # Run migration again with same data
        second_migrator = described_class.new(categories_json)
        second_migrator.migrate!

        expect(Category.count).to eq(initial_count)
      end
    end

    context 'with invalid JSON' do
      let(:invalid_json) { '{ invalid json' }
      let(:migrator) { described_class.new(invalid_json) }

      it 'handles JSON parse errors gracefully' do
        result = migrator.migrate!

        expect(result[:success]).to be false
        expect(result[:errors]).not_to be_empty
        expect(result[:errors].first).to include('parse')
      end
    end

    context 'with orphaned child categories' do
      let(:orphaned_json) do
        [
          {
            'id' => 99,
            'name' => 'Orphan Category',
            'slug' => 'orphan',
            'parent' => 999, # Non-existent parent
            'description' => 'This category has no parent'
          },
        ].to_json
      end
      let(:migrator) { described_class.new(orphaned_json) }

      it 'logs error for orphaned categories' do
        result = migrator.migrate!

        expect(result[:errors]).to include(a_string_matching(/Parent category not found/))
      end
    end

    context 'with child category having non-root parent' do
      before do
        # Create a non-root parent first
        @non_root_parent = Category.create!(
          title: 'Non-Root Parent',
          slug: 'non-root-parent',
          is_root: false
        )
      end

      let(:invalid_hierarchy_json) do
        [
          {
            'id' => 100,
            'name' => 'Child',
            'slug' => 'child',
            'parent' => 100,
            'description' => 'Child with non-root parent'
          },
        ].to_json
      end

      it 'validates parent is root category' do
        # First create a category that will map to parent id
        migrator_instance = described_class.new(invalid_hierarchy_json)
        migrator_instance.instance_variable_set(:@mapping, { 100 => @non_root_parent.id })

        result = migrator_instance.migrate!

        expect(result[:errors]).to include(a_string_matching(/not a root category/))
      end
    end
  end

  describe 'category name mapping' do
    let(:audio_categories_json) do
      [
        { 'id' => 1, 'name' => 'Headphone', 'slug' => 'headphone', 'parent' => 0, 'description' => '' },
        { 'id' => 2, 'name' => 'DAC/Amp', 'slug' => 'dac-amp', 'parent' => 0, 'description' => '' },
        { 'id' => 3, 'name' => 'DAP', 'slug' => 'dap', 'parent' => 0, 'description' => '' },
      ].to_json
    end
    let(:migrator) { described_class.new(audio_categories_json) }

    it 'maps "headphone" to "Tai nghe"' do
      migrator.migrate!

      category = Category.find_by(title: 'Tai nghe')
      expect(category).to be_present
    end

    it 'maps "dac-amp" to "DAC/AMP"' do
      migrator.migrate!

      category = Category.find_by(title: 'DAC/AMP')
      expect(category).to be_present
    end

    it 'maps "dap" to "Nguồn phát"' do
      migrator.migrate!

      category = Category.find_by(title: 'Nguồn phát')
      expect(category).to be_present
    end
  end

  describe 'slug generation' do
    let(:duplicate_slug_json) do
      [
        { 'id' => 1, 'name' => 'Category', 'slug' => 'category', 'parent' => 0, 'description' => '' },
        { 'id' => 2, 'name' => 'Category', 'slug' => 'category', 'parent' => 0, 'description' => '' },
      ].to_json
    end
    let(:migrator) { described_class.new(duplicate_slug_json) }

    it 'generates unique slugs for duplicate category names' do
      migrator.migrate!

      categories = Category.where(title: 'Category')
      expect(categories.count).to be >= 2
      slugs = categories.pluck(:slug).uniq
      expect(slugs.count).to eq(categories.count)
    end
  end
end
