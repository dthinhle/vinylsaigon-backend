require 'rails_helper'

RSpec.describe ProductService, type: :service do
  describe 'PartialUpdateResult' do
    let(:product) { create(:product) }
    let(:result) { ProductService::PartialUpdateResult.new(product) }

    it 'initializes with product and success true' do
      expect(result.product).to eq(product)
      expect(result.success).to be true
      expect(result.warnings).to be_empty
      expect(result.errors).to be_empty
    end

    describe '#add_warning' do
      it 'adds warning message' do
        result.add_warning('Test warning')
        expect(result.warnings).to include('Test warning')
        expect(result.success).to be true
      end
    end

    describe '#add_error' do
      it 'adds error message and sets success to false' do
        result.add_error('Test error')
        expect(result.errors).to include('Test error')
        expect(result.success).to be false
      end
    end

    describe '#partial_success?' do
      it 'returns true when success is true and warnings exist' do
        result.add_warning('Warning')
        expect(result.partial_success?).to be true
      end

      it 'returns false when no warnings' do
        expect(result.partial_success?).to be false
      end

      it 'returns false when errors exist' do
        result.add_error('Error')
        result.add_warning('Warning')
        expect(result.partial_success?).to be false
      end
    end
  end

  describe '.create_product' do
    let(:product_params) do
      {
        name: 'Test Product',
        sku: 'TEST-SKU',
        slug: 'test-product',
        description: 'Test description',
        status: 'active'
      }
    end

    context 'with no variants' do
      it 'creates product with default variant' do
        product = ProductService.create_product(product_params)

        expect(product).to be_persisted
        expect(product.product_variants.count).to eq(1)
        expect(product.product_variants.first.name).to eq('Default')
        expect(product.product_variants.first.sku).to eq('TEST-SKU')
      end
    end

    context 'with single variant' do
      let(:variant_params) do
        {
          '0' => {
            name: 'Variant 1',
            sku: 'TEST-SKU-VAR-1',
            slug: 'variant-1',
            original_price: 100,
            current_price: 90
          }
        }
      end

      it 'creates product with single variant' do
        product = ProductService.create_product(
          product_params.merge(original_price: 100, current_price: 90),
          variant_params
        )

        expect(product).to be_persisted
        expect(product.product_variants.count).to eq(1)

        variant = product.product_variants.first
        expect(variant.name).to eq('Default')
        expect(variant.original_price).to eq(100)
        expect(variant.current_price).to eq(90)
      end
    end

    context 'with multiple variants' do
      let(:variant_params) do
        {
          '0' => {
            name: 'Variant 1',
            sku: 'TEST-SKU-VAR-1',
            slug: 'variant-1',
            original_price: 100,
            current_price: 90
          },
          '1' => {
            name: 'Variant 2',
            sku: 'TEST-SKU-VAR-2',
            slug: 'variant-2',
            original_price: 120,
            current_price: 110
          }
        }
      end

      it 'creates product with multiple variants' do
        product = ProductService.create_product(product_params, variant_params)

        expect(product).to be_persisted
        expect(product.product_variants.count).to eq(2)
        expect(product.product_variants.pluck(:name)).to match_array(['Variant 1', 'Variant 2'])
      end
    end

    context 'with transaction rollback' do
      let(:invalid_variant_params) do
        {
          '0' => {
            name: '',
            sku: '',
            slug: '',
            original_price: nil
          }
        }
      end

      it 'rolls back product creation on variant error' do
        expect {
          ProductService.create_product(product_params, invalid_variant_params)
        }.to raise_error(ActiveRecord::RecordInvalid)

        expect(Product.find_by(sku: 'TEST-SKU')).to be_nil
      end
    end
  end

  describe '.update_product' do
    let(:product) { create(:product, name: 'Original Name') }
    let(:product_params) { { name: 'Updated Name' } }

    context 'successful update' do
      it 'updates product attributes' do
        result = ProductService.update_product(product, product_params)

        expect(result.success).to be true
        expect(product.reload.name).to eq('Updated Name')
      end
    end

    context 'with variant updates' do
      let(:product) { create(:product) }
      let(:variant_params) do
        {
          '0' => {
            sku: product.product_variants.first.sku,
            name: 'Updated Variant',
            original_price: 150
          }
        }
      end

      it 'updates existing variants' do
        result = ProductService.update_product(product, product_params, variant_params)

        expect(result.success).to be true
        expect(product.product_variants.first.reload.name).to eq('Default')
        expect(product.product_variants.first.original_price).to eq(150)
      end
    end

    context 'with error handling' do
      it 'captures errors and returns result object' do
        allow(product).to receive(:update!).and_raise(StandardError.new('Update failed'))

        result = ProductService.update_product(product, product_params)

        expect(result.success).to be false
        expect(result.errors).to include('Update failed')
      end
    end
  end

  describe '.sanitize_variant_params' do
    let(:product) { create(:product, sku: 'PROD-SKU') }

    context 'with valid params' do
      let(:variant_params) do
        {
          '0' => { name: 'Variant 1', sku: 'VAR-1' },
          '1' => { name: 'Variant 2', sku: 'VAR-2' }
        }
      end

      it 'returns sanitized params' do
        result = ProductService.sanitize_variant_params(product, variant_params)
        expect(result.length).to eq(2)
        expect(result.map { |v| v[:sku] }).to match_array(['VAR-1', 'VAR-2'])
      end
    end

    context 'with blank SKU' do
      let(:variant_params) do
        {
          '0' => { name: 'Test Variant', sku: '' }
        }
      end

      it 'auto-generates SKU from product SKU and variant name' do
        result = ProductService.sanitize_variant_params(product, variant_params)
        expect(result.first[:sku]).to eq('PROD-SKU-test-variant')
      end
    end

    context 'with destroyed variants' do
      let(:variant_params) do
        {
          '0' => { name: 'Variant 1', sku: 'VAR-1', _destroy: '1' },
          '1' => { name: 'Variant 2', sku: 'VAR-2' }
        }
      end

      it 'filters out destroyed variants' do
        result = ProductService.sanitize_variant_params(product, variant_params)
        expect(result.length).to eq(1)
        expect(result.first[:sku]).to eq('VAR-2')
      end
    end

    context 'with duplicate SKUs' do
      let(:variant_params) do
        {
          '0' => { name: 'Variant 1', sku: 'DUPLICATE' },
          '1' => { name: 'Variant 2', sku: 'DUPLICATE' }
        }
      end

      it 'raises error for duplicate SKUs in submission' do
        expect {
          ProductService.sanitize_variant_params(product, variant_params)
        }.to raise_error(StandardError, /Duplicate SKU/)
      end
    end

    context 'with existing SKU in another product' do
      let!(:other_product) { create(:product) }
      let!(:existing_variant) { create(:product_variant, product: other_product, sku: 'EXISTING-SKU') }
      let(:variant_params) do
        {
          '0' => { name: 'Variant 1', sku: 'EXISTING-SKU' }
        }
      end

      it 'raises error for SKU existing in another product' do
        expect {
          ProductService.sanitize_variant_params(product, variant_params)
        }.to raise_error(StandardError, /already exists/)
      end
    end
  end

  describe '.sync_variants' do
    let(:product) { create(:product) }
    let!(:existing_variant) { product.product_variants.first }
    let!(:to_remove_variant) { create(:product_variant, product: product, sku: 'REMOVE-1') }

    let(:sanitized_params) do
      [
        { sku: existing_variant.sku, name: 'Updated Name', original_price: 150 },
        { sku: 'NEW-1', name: 'New Variant', original_price: 200, slug: 'new-1' },
      ]
    end

    it 'updates existing variants' do
      ProductService.sync_variants(product, sanitized_params)
      expect(existing_variant.reload.name).to eq('Updated Name')
      expect(existing_variant.original_price).to eq(150)
    end

    it 'creates new variants' do
      expect {
        ProductService.sync_variants(product, sanitized_params)
      }.to change { product.reload.product_variants.count }.by(1)

      expect(product.product_variants.find_by(sku: 'NEW-1')).to be_present
    end

    it 'does nothing when params are empty' do
      expect {
        ProductService.sync_variants(product, [])
      }.not_to change { product.product_variants.count }
    end
  end

  describe '.handle_single_variant' do
    let(:product) { create(:product, sku: 'PROD-SKU', slug: 'prod-slug') }
    let(:variant) { product.product_variants.first }
    let(:product_params) { { original_price: 100, current_price: 90 } }

    it 'updates variant with default properties' do
      ProductService.handle_single_variant(product, product_params, nil, nil)
      variant.reload

      expect(variant.name).to eq('Default')
      expect(variant.sku).to eq('PROD-SKU')
      expect(variant.slug).to eq('prod-slug')
      expect(variant.original_price).to eq(100)
      expect(variant.current_price).to eq(90)
      expect(variant.status).to eq('active')
    end
  end

  describe '.handle_multiple_variants' do
    let(:product) { create(:product) }
    let!(:variant1) { create(:product_variant, product: product, sku: 'VAR-1') }
    let!(:variant2) { create(:product_variant, product: product, sku: 'VAR-2') }

    let(:variant_params) do
      {
        '0' => {
          sku: 'VAR-1',
          images: [],
          remove_image_ids: []
        }
      }
    end

    it 'processes variants without errors' do
      expect {
        ProductService.handle_multiple_variants(product, variant_params)
      }.not_to raise_error
    end

    it 'skips destroyed variants' do
      variant_params['0'][:_destroy] = '1'

      expect(ProductService).not_to receive(:update_images_advanced)
      ProductService.handle_multiple_variants(product, variant_params)
    end
  end

  describe '.create_default_variant' do
    it 'creates default variant for new product' do
      product = build(:product, sku: 'TEST-SKU', slug: 'test-slug')
      product.product_variants.clear
      product.save!

      ProductService.create_default_variant(product)

      variant = product.product_variants.first
      expect(variant.name).to eq('Default')
      expect(variant.sku).to eq('TEST-SKU')
      expect(variant.slug).to eq('test-slug')
      expect(variant.original_price).to eq(0)
      expect(variant.status).to eq('active')
    end
  end

  describe '.destroy_selected_products' do
    context 'with valid product IDs' do
      it 'destroys selected products' do
        product1 = create(:product)
        product2 = create(:product)

        result = ProductService.destroy_selected_products([product1.id, product2.id])

        expect(result[:success]).to be true
        expect(result[:message]).to eq('Selected products deleted successfully.')
        expect(Product.exists?(product1.id)).to be false
        expect(Product.exists?(product2.id)).to be false
      end
    end

    context 'with non-existent IDs' do
      it 'reports not found products' do
        product1 = create(:product)

        result = ProductService.destroy_selected_products([product1.id, 99999])

        expect(result[:success]).to be false
        expect(result[:not_found]).to include(99999)
        expect(result[:message]).to include('Products not found: 99999')
      end
    end

    context 'with empty array' do
      it 'returns failure message' do
        result = ProductService.destroy_selected_products([])

        expect(result[:success]).to be false
        expect(result[:message]).to eq('No products selected for deletion.')
      end
    end

    context 'with mixed valid and invalid IDs' do
      it 'destroys valid products and reports invalid ones' do
        product1 = create(:product)

        result = ProductService.destroy_selected_products([product1.id, 99999])

        expect(result[:success]).to be false
        expect(result[:not_found]).to include(99999)
        expect(result[:message]).to include('Products not found: 99999')
        expect(Product.exists?(product1.id)).to be false
      end
    end
  end

  describe '.related_products' do
    let(:root_category) { create(:category, :root) }
    let(:category1) { create(:category, parent: root_category) }
    let(:category2) { create(:category, parent: root_category) }

    let!(:product1) { create(:product, category: category1, status: 'active') }
    let!(:related_product1) { create(:product, category: category2, status: 'active', updated_at: 2.months.ago) }
    let!(:related_product2) { create(:product, category: category2, status: 'active', updated_at: 1.month.ago) }

    before do
      create(:product_variant, product: product1)
      create(:product_variant, product: related_product1)
      create(:product_variant, product: related_product2)
    end

    it 'returns related products from same category tree' do
      result = ProductService.related_products([product1], limit: 8)

      expect(result).to be_an(Array)
      expect(result).not_to include(product1)
    end

    it 'respects the limit parameter' do
      result = ProductService.related_products([product1], limit: 2)

      expect(result.length).to be <= 2
    end

    it 'returns empty array when no categories' do
      product_without_category = create(:product, category: nil)
      result = ProductService.related_products([product_without_category], limit: 8)

      expect(result).to eq([])
    end

    it 'excludes the original product from results' do
      result = ProductService.related_products([product1], limit: 8)

      expect(result).not_to include(product1)
    end
  end

  describe '.other_products' do
    let(:category) { create(:category) }
    let(:product) { create(:product, category: category) }

    let!(:same_category_product1) { create(:product, category: category, status: 'active', updated_at: 2.months.ago) }
    let!(:same_category_product2) { create(:product, category: category, status: 'active', updated_at: 1.month.ago) }
    let!(:different_category_product) { create(:product, status: 'active', updated_at: 1.month.ago) }
    let!(:old_product) { create(:product, category: category, status: 'active', updated_at: 4.months.ago) }

    it 'returns products from same category' do
      result = ProductService.other_products(product, limit: 8)

      expect(result).to be_an(Array)
      result.each do |p|
        expect(p.category).to eq(category)
      end
    end

    it 'filters by updated_at within 3 months' do
      result = ProductService.other_products(product, limit: 8)

      expect(result).not_to include(old_product)
    end

    it 'only returns active products' do
      inactive_product = create(:product, category: category, status: 'inactive', updated_at: 1.month.ago)
      result = ProductService.other_products(product, limit: 8)

      expect(result).not_to include(inactive_product)
    end

    it 'respects the limit parameter' do
      result = ProductService.other_products(product, limit: 2)

      expect(result.length).to be <= 2
    end
  end

  describe 'private methods' do
    describe '.fetch_tier1_products' do
      it 'fetches products from related categories' do
        root_category = create(:category, :root)
        category1 = create(:category, parent: root_category)
        category2 = create(:category, parent: root_category)

        create(:product, category: category2, status: 'active')

        used_ids = []
        related_products = []

        ProductService.send(:fetch_tier1_products, [category1], 8, used_ids, related_products)

        expect(related_products).to be_an(Array)
      end
    end

    describe '.fetch_tier2_products' do
      it 'fetches products from parent categories' do
        root_category = create(:category, :root)
        child_category = create(:category, parent: root_category)

        create(:product, category: root_category, status: 'active')

        used_ids = []
        related_products = []

        ProductService.send(:fetch_tier2_products, [child_category], 8, used_ids, related_products)

        expect(related_products).to be_an(Array)
      end
    end

    describe '.fetch_tier3_products' do
      it 'fetches random recent products' do
        create_list(:product, 5, status: 'active', updated_at: 1.month.ago)

        used_ids = []
        related_products = []

        ProductService.send(:fetch_tier3_products, 3, used_ids, related_products)

        expect(related_products.length).to be <= 3
      end
    end

    describe '.permit_variant_attributes' do
      let(:variant_attrs) do
        {
          id: 1,
          name: 'Test',
          sku: 'SKU-1',
          slug: 'test',
          original_price: 100,
          current_price: 90,
          status: 'active',
          sort_order: 1,
          unpermitted_field: 'should be filtered'
        }
      end

      it 'permits only allowed attributes' do
        result = ProductService.send(:permit_variant_attributes, variant_attrs)

        expect(result.keys).to include('id', 'name', 'sku', 'slug', 'original_price', 'current_price', 'status', 'sort_order')
        expect(result.keys).not_to include('unpermitted_field')
      end
    end
  end
end
