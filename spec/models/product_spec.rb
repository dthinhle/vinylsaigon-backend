# == Schema Information
#
# Table name: products
#
#  id                   :bigint           not null, primary key
#  deleted_at           :datetime
#  description          :jsonb            not null
#  featured             :boolean          default(FALSE), not null
#  flags                :string           default([]), is an Array
#  free_installment_fee :boolean          default(TRUE), not null
#  gift_content         :jsonb            not null
#  legacy_attributes    :jsonb
#  low_stock_threshold  :integer          default(5), not null
#  meta_description     :string(500)
#  meta_title           :string(255)
#  name                 :string           not null
#  price_updated_at     :datetime
#  product_attributes   :jsonb
#  product_tags         :string           default([]), is an Array
#  short_description    :jsonb            not null
#  sku                  :string           not null
#  slug                 :string
#  sort_order           :integer          default(0), not null
#  status               :string           default("inactive"), not null
#  stock_quantity       :integer          default(0), not null
#  stock_status         :string           default("in_stock"), not null
#  warranty_months      :integer
#  weight               :decimal(8, 2)
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  category_id          :bigint
#  legacy_wp_id         :integer
#
# Indexes
#
#  index_products_on_category_id  (category_id)
#  index_products_on_deleted_at   (deleted_at)
#  index_products_on_sku          (sku) UNIQUE
#  index_products_on_slug         (slug) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (category_id => categories.id)
#
require 'rails_helper'

RSpec.describe Product, type: :model do
  describe 'associations' do
    it { should belong_to(:category).optional }
    it { should have_many(:product_variants).dependent(:destroy) }
    it { should have_and_belong_to_many(:product_collections) }
    it { should have_and_belong_to_many(:brands) }
    it { should have_many(:blog_products).dependent(:destroy) }
    it { should have_many(:blogs).through(:blog_products) }
  end

  describe 'validations' do
    subject { build(:product) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:sku) }
    it { should validate_uniqueness_of(:sku) }
    it { should validate_presence_of(:status) }
    it { should validate_presence_of(:stock_status) }
    it { should validate_numericality_of(:stock_quantity).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:low_stock_threshold).is_greater_than_or_equal_to(0) }
    it { should validate_length_of(:short_description).is_at_most(500) }
    it { should validate_length_of(:meta_title).is_at_most(255) }
    it { should validate_length_of(:meta_description).is_at_most(500) }
  end

  describe 'enums' do
    it 'defines status enum with string values' do
      expect(Product.statuses).to eq('active' => 'active', 'inactive' => 'inactive', 'discontinued' => 'discontinued')
    end

    it 'defines stock_status enum with string values' do
      expect(Product.stock_statuses).to eq('in_stock' => 'in_stock', 'out_of_stock' => 'out_of_stock', 'low_stock' => 'low_stock')
    end
  end

  describe 'scopes' do
    describe '.on_sale' do
      let!(:product_with_discount) { create(:product) }
      let!(:product_with_gift) { create(:product, :with_gift) }
      let!(:regular_product) { create(:product) }

      before do
        create(:product_variant, product: product_with_discount, original_price: 100, current_price: 80)
        create(:product_variant, product: product_with_gift, original_price: 100, current_price: nil)
        create(:product_variant, product: regular_product, original_price: 100, current_price: nil)
      end

      it 'includes products with discounted variants' do
        expect(Product.on_sale).to include(product_with_discount)
      end

      it 'includes products with gift content' do
        expect(Product.on_sale).to include(product_with_gift)
      end

      it 'excludes regular products' do
        expect(Product.on_sale).not_to include(regular_product)
      end
    end
  end

  describe 'callbacks' do
    describe '#ensure_default_variant' do
      it 'creates a default variant after product creation' do
        product = create(:product)
        expect(product.product_variants.count).to eq(1)
      end

      it 'sets default variant properties correctly' do
        product = create(:product, sku: 'TEST-SKU', slug: 'test-slug')
        variant = product.product_variants.first

        expect(variant.name).to eq('Default')
        expect(variant.sku).to eq('TEST-SKU')
        expect(variant.slug).to eq('test-slug')
        expect(variant.original_price).to eq(0)
        expect(variant.status).to eq('active')
      end

      it 'does not create variant if variants already exist' do
        product = build(:product)
        product.product_variants.build(name: 'Custom', sku: 'CUSTOM-SKU', slug: 'custom', original_price: 100)
        product.save!

        expect(product.product_variants.count).to eq(1)
        expect(product.product_variants.first.name).to eq('Default')
      end
    end

    describe '#trigger_collection_update' do
      it 'triggers CollectionGeneratorJob when product is active' do
        expect(CollectionGeneratorJob).to receive(:perform_later)
        create(:product, status: 'active')
      end

      it 'triggers CollectionGeneratorJob when status changes to active' do
        product = create(:product, status: 'inactive')
        expect(CollectionGeneratorJob).to receive(:perform_later)
        product.update(status: 'active')
      end

      it 'triggers CollectionGeneratorJob when status changes from active' do
        product = create(:product, status: 'active')
        expect(CollectionGeneratorJob).to receive(:perform_later)
        product.update(status: 'inactive')
      end
    end

    describe '#reindex_product_variants' do
      it 'triggers ProductIndexJob after create' do
        expect(ProductIndexJob).to receive(:perform_later).at_least(:once)
        create(:product)
      end

      it 'triggers ProductIndexJob after update' do
        product = create(:product)
        expect(ProductIndexJob).to receive(:perform_later).with(product.id)
        product.update(name: 'Updated Name')
      end
    end
  end

  describe 'custom validations' do
    describe '#flags_inclusion' do
      it 'accepts valid flags' do
        product = build(:product, flags: ['just arrived'])
        expect(product).to be_valid
      end

      it 'rejects invalid flags' do
        product = build(:product, flags: ['invalid flag'])
        expect(product).not_to be_valid
        expect(product.errors[:flags]).to include('contain invalid value(s): invalid flag')
      end

      it 'accepts empty flags array' do
        product = build(:product, flags: [])
        expect(product).to be_valid
      end
    end

    describe '#validate_product_variants' do
      it 'requires at least one variant' do
        product = build(:product)
        product.product_variants.build(name: 'Valid', sku: 'VALID', slug: 'valid', original_price: 100)
        product.save!

        expect(product.product_variants.count).to eq(1)
      end

      it 'propagates variant errors to product' do
        product = build(:product)
        product.product_variants.build(name: '', sku: '', slug: '', original_price: nil)
        expect(product).not_to be_valid
        expect(product.errors[:base].any? { |e| e.include?('Variant error') }).to be true
      end
    end
  end

  describe 'instance methods' do
    describe '#images' do
      let(:product) { create(:product) }

      it 'returns empty array when variants have no images' do
        expect(product.images).to be_empty
      end

      it 'aggregates images from all variants' do
        variant1 = create(:product_variant, :with_images, product: product)
        variant2 = create(:product_variant, :with_images, product: product)

        expect(product.reload.images.count).to eq(6)
      end
    end

    describe '#current_price' do
      let(:product) { create(:product) }

      context 'with single variant' do
        it 'returns the variant current_price' do
          variant = product.product_variants.first
          variant.update(current_price: 90)

          expect(product.current_price).to eq(90)
        end

        it 'returns nil when variant has no current_price' do
          variant = product.product_variants.first
          variant.update(current_price: nil)

          expect(product.current_price).to be_nil
        end
      end

      context 'with multiple variants' do
        it 'returns minimum current_price excluding nils' do
          product_multi = build(:product)
          product_multi.product_variants.clear
          product_multi.product_variants.build(name: 'V1', sku: 'V1', slug: 'v1', original_price: 100, current_price: 80)
          product_multi.product_variants.build(name: 'V2', sku: 'V2', slug: 'v2', original_price: 100, current_price: 90)
          product_multi.product_variants.build(name: 'V3', sku: 'V3', slug: 'v3', original_price: 100, current_price: 70)
          product_multi.save!

          expect(product_multi.current_price).to eq(70)
        end

        it 'handles nil current_price values' do
          product_nil = build(:product)
          product_nil.product_variants.clear
          product_nil.product_variants.build(name: 'V1', sku: 'V1', slug: 'v1', original_price: 100, current_price: 80)
          product_nil.product_variants.build(name: 'V2', sku: 'V2', slug: 'v2', original_price: 100, current_price: nil)
          product_nil.save!

          expect(product_nil.current_price).to eq(80)
        end
      end
    end

    describe '#original_price' do
      let(:product) { create(:product) }

      context 'with single variant' do
        it 'returns the variant original_price' do
          variant = product.product_variants.first
          variant.update(original_price: 100)

          expect(product.original_price).to eq(100)
        end
      end

      context 'with multiple variants' do
        before do
          create(:product_variant, product: product, original_price: 100)
          create(:product_variant, product: product, original_price: 150)
          create(:product_variant, product: product, original_price: 120)
        end

        it 'returns maximum original_price' do
          expect(product.reload.original_price).to eq(150)
        end
      end
    end
  end

  describe 'nested attributes' do
    it 'accepts nested attributes for product_variants' do
      product = create(:product)
      product.update(
        product_variants_attributes: [
          { id: product.product_variants.first.id, name: 'Updated Variant' },
        ]
      )

      expect(product.product_variants.first.name).to eq('Default')
    end

    it 'allows destroying variants through nested attributes' do
      product = create(:product)
      create_list(:product_variant, 3, product: product)

      expect {
        product.update(
          product_variants_attributes: [
            { id: product.product_variants.last.id, _destroy: '1' },
          ]
        )
      }.to change { product.product_variants.count }.by(-1)
    end
  end

  describe 'automatic flag management' do
    describe 'arrive_soon flag' do
      context 'on product creation' do
        it 'auto-adds arrive_soon when created without prices' do
          product = build(:product)
          product.product_variants.clear
          product.product_variants.build(name: 'Default', sku: 'TEST', slug: 'test', original_price: nil, current_price: nil)
          product.save!

          expect(product.reload.flags).to include(Product::FLAGS[:arrive_soon])
        end

        it 'does not add arrive_soon when created with prices' do
          product = build(:product)
          product.product_variants.clear
          product.product_variants.build(name: 'Default', sku: 'TEST', slug: 'test', original_price: 100, current_price: 90)
          product.save!

          expect(product.reload.flags).not_to include(Product::FLAGS[:arrive_soon])
        end

        it 'does not add arrive_soon when skip_auto_flags is true' do
          product = build(:product)
          product.skip_auto_flags = true
          product.product_variants.clear
          product.product_variants.build(name: 'Default', sku: 'TEST', slug: 'test', original_price: nil, current_price: nil)
          product.save!

          expect(product.reload.flags).not_to include(Product::FLAGS[:arrive_soon])
        end
      end

      context 'after creation' do
        it 'does not auto-add arrive_soon when updating to no prices' do
          product = create(:product)
          variant = product.product_variants.first
          variant.update!(original_price: 100, current_price: 90)
          product.reload

          variant.update!(original_price: nil, current_price: nil)
          product.reload

          expect(product.flags).not_to include(Product::FLAGS[:arrive_soon])
        end

        it 'can be manually added after creation even with prices' do
          product = create(:product)
          variant = product.product_variants.first
          variant.update!(original_price: 100, current_price: 90)

          product.skip_auto_flags = true
          product.update!(flags: [Product::FLAGS[:arrive_soon]])

          expect(product.reload.flags).to include(Product::FLAGS[:arrive_soon])
        end
      end
    end

    describe 'just_arrived flag' do
      context 'when prices change from nil to present' do
        it 'auto-adds just_arrived in console (without skip_auto_flags)' do
          product = build(:product)
          product.product_variants.clear
          product.product_variants.build(name: 'Default', sku: 'TEST', slug: 'test', original_price: nil, current_price: nil)
          product.save!

          variant = product.product_variants.first
          variant.update!(original_price: 100)
          product.reload

          expect(product.flags).to include(Product::FLAGS[:just_arrived])
        end

        it 'does not add just_arrived when skip_auto_flags is true' do
          product = build(:product)
          product.product_variants.clear
          product.product_variants.build(name: 'Default', sku: 'TEST', slug: 'test', original_price: nil, current_price: nil)
          product.save!

          product.skip_auto_flags = true
          variant = product.product_variants.first
          variant.update!(original_price: 100)
          product.reload

          expect(product.flags).not_to include(Product::FLAGS[:just_arrived])
        end

        it 'removes arrive_soon when just_arrived is added' do
          product = build(:product)
          product.product_variants.clear
          product.product_variants.build(name: 'Default', sku: 'TEST', slug: 'test', original_price: nil, current_price: nil)
          product.save!

          expect(product.reload.flags).to include(Product::FLAGS[:arrive_soon])

          variant = product.product_variants.first
          variant.update!(original_price: 100)
          product.reload

          expect(product.flags).to include(Product::FLAGS[:just_arrived])
          expect(product.flags).not_to include(Product::FLAGS[:arrive_soon])
        end
      end

      context 'mutual exclusivity with arrive_soon' do
        it 'removes arrive_soon when both flags are present' do
          product = create(:product)
          variant = product.product_variants.first
          variant.update!(original_price: 100)

          product.update!(flags: [Product::FLAGS[:arrive_soon], Product::FLAGS[:just_arrived]])
          product.reload

          expect(product.flags).to include(Product::FLAGS[:just_arrived])
          expect(product.flags).not_to include(Product::FLAGS[:arrive_soon])
        end
      end
    end

    describe 'multiple variants scenario' do
      it 'only adds arrive_soon on creation when ALL variants lack prices' do
        product = build(:product)
        product.product_variants.clear
        product.product_variants.build(name: 'V1', sku: 'V1', slug: 'v1', original_price: nil, current_price: nil)
        product.product_variants.build(name: 'V2', sku: 'V2', slug: 'v2', original_price: 100, current_price: 90)
        product.save!

        expect(product.reload.flags).not_to include(Product::FLAGS[:arrive_soon])
      end

      it 'adds arrive_soon when all variants lack prices on creation' do
        product = build(:product)
        product.product_variants.clear
        product.product_variants.build(name: 'V1', sku: 'V1', slug: 'v1', original_price: nil, current_price: nil)
        product.product_variants.build(name: 'V2', sku: 'V2', slug: 'v2', original_price: nil, current_price: nil)
        product.save!

        expect(product.reload.flags).to include(Product::FLAGS[:arrive_soon])
      end
    end
  end
end
