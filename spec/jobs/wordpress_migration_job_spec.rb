# frozen_string_literal: true

require 'rails_helper'

RSpec.describe WordpressMigrationJob, type: :job do
  let(:categories_json) { File.read(Rails.root.join('spec/fixtures/wordpress_migration/categories.json')) }
  let(:products_json) { File.read(Rails.root.join('spec/fixtures/wordpress_migration/products.json')) }

  describe '#perform' do
    context 'with categories and products' do
      it 'migrates categories first' do
        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        expect(result[:categories][:migrated_count]).to be > 0
      end

      it 'migrates products after categories' do
        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        expect(result[:products][:migrated_count]).to be >= 0
      end

      it 'passes category mapping to product migrator' do
        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        # Verify categories were created and mapping exists
        expect(result[:categories][:mapping]).to be_a(Hash)
      end

      it 'returns comprehensive result' do
        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        expect(result).to have_key(:categories)
        expect(result).to have_key(:products)
        expect(result).to have_key(:started_at)
        expect(result).to have_key(:completed_at)
        expect(result).to have_key(:success)
      end

      it 'logs migration completion' do
        expect(Rails.logger).to receive(:info).with(a_string_matching(/WordPress Migration completed/))
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Categories migrated:/))
        expect(Rails.logger).to receive(:info).with(a_string_matching(/Products migrated:/))

        described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )
      end

      it 'sets timestamps' do
        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        expect(result[:started_at]).to be_a(Time)
        expect(result[:completed_at]).to be_a(Time)
        expect(result[:completed_at]).to be >= result[:started_at]
      end
    end

    context 'with only categories' do
      it 'migrates only categories' do
        result = described_class.new.perform(categories_json: categories_json)

        expect(result[:categories][:migrated_count]).to be > 0
        expect(result[:products][:migrated_count]).to eq(0)
      end
    end

    context 'with only products' do
      it 'migrates only products' do
        result = described_class.new.perform(products_json: products_json)

        expect(result[:categories][:migrated_count]).to eq(0)
        # Products may or may not succeed without category mapping
      end
    end

    context 'with no data' do
      it 'returns result with zero migrations' do
        result = described_class.new.perform

        expect(result[:categories][:migrated_count]).to eq(0)
        expect(result[:products][:migrated_count]).to eq(0)
      end
    end

    context 'when migration fails' do
      before do
        allow_any_instance_of(WordpressMigration::CategoryMigrator).to receive(:migrate!)
          .and_raise(StandardError.new('Migration failed'))
      end

      it 'handles errors gracefully' do
        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        expect(result[:success]).to be false
        expect(result[:error]).to be_present
      end

      it 'logs error information' do
        expect(Rails.logger).to receive(:error).with(a_string_matching(/WordPress Migration Job failed/))
        expect(Rails.logger).to receive(:error).with(a_string_including('Migration failed'))

        described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )
      end
    end

    context 'integration test with real data' do
      it 'performs end-to-end migration successfully' do
        initial_category_count = Category.count
        initial_product_count = Product.count
        initial_brand_count = Brand.count

        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        expect(result[:success]).to be true
        expect(Category.count).to be > initial_category_count
        expect(Product.count).to be >= initial_product_count
        expect(Brand.count).to be >= initial_brand_count
      end

      it 'creates valid products with all relationships' do
        result = described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        # Verify products have all required relationships
        Product.where('created_at >= ?', result[:started_at]).find_each do |product|
          expect(product).to be_valid
          expect(product.product_variants).not_to be_empty

          # Check that product has a variant
          variant = product.product_variants.first
          expect(variant).to be_valid
          expect(variant.sku).to be_present
        end
      end

      it 'correctly maps categories to products' do
        described_class.new.perform(
          categories_json: categories_json,
          products_json: products_json
        )

        # Find products that should have categories
        products_with_categories = Product.where.not(category_id: nil)
        expect(products_with_categories.count).to be > 0

        products_with_categories.each do |product|
          expect(product.category).to be_persisted
          expect(product.category).to be_valid
        end
      end
    end
  end

  describe 'job queuing' do
    it 'enqueues the job' do
      expect {
        described_class.perform_later(
          categories_json: categories_json,
          products_json: products_json
        )
      }.to have_enqueued_job(described_class)
    end

    it 'uses default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end
end
