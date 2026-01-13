# == Schema Information
#
# Table name: product_variants
#
#  id                 :bigint           not null, primary key
#  current_price      :decimal(, )
#  deleted_at         :datetime
#  name               :string           not null
#  original_price     :decimal(, )
#  short_description  :string(80)
#  sku                :string           not null
#  slug               :string
#  sort_order         :integer
#  status             :string           default("active"), not null
#  stock_quantity     :integer
#  variant_attributes :jsonb
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  product_id         :bigint           not null
#
# Indexes
#
#  index_product_variants_on_deleted_at          (deleted_at)
#  index_product_variants_on_product_id          (product_id)
#  index_product_variants_on_product_id_and_sku  (product_id,sku) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (product_id => products.id)
#
require 'rails_helper'

RSpec.describe ProductVariant, type: :model do
  describe 'associations' do
    it { should belong_to(:product) }
  end

  describe 'validations' do
    subject { build(:product_variant) }

    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:sku) }
    it { should validate_presence_of(:status) }
    it { should validate_numericality_of(:original_price).is_greater_than_or_equal_to(0) }
    it { should validate_numericality_of(:current_price).is_greater_than_or_equal_to(0).allow_nil }
    it { should validate_numericality_of(:stock_quantity).is_greater_than_or_equal_to(0).only_integer.allow_nil }
    it { should validate_numericality_of(:sort_order).is_greater_than_or_equal_to(0).only_integer.allow_nil }

    describe 'sku uniqueness scoped to product' do
      let(:product) { create(:product) }
      let!(:variant1) { create(:product_variant, product: product, sku: 'UNIQUE-SKU') }

      it 'allows same SKU for different products' do
        other_product = create(:product)
        variant2 = build(:product_variant, product: other_product, sku: 'UNIQUE-SKU')
        expect(variant2).to be_valid
      end

      it 'does not allow duplicate SKU within same product' do
        variant2 = build(:product_variant, product: product, sku: 'UNIQUE-SKU')
        expect(variant2).not_to be_valid
        expect(variant2.errors[:sku]).to include('has already been taken')
      end
    end

    describe 'slug uniqueness scoped to product' do
      let(:product) { create(:product) }
      let!(:variant1) { create(:product_variant, product: product, slug: 'unique-slug') }

      it 'allows same slug for different products' do
        other_product = create(:product)
        variant2 = build(:product_variant, product: other_product, slug: 'unique-slug')
        expect(variant2).to be_valid
      end

      it 'does not allow duplicate slug within same product' do
        variant2 = build(:product_variant, product: product, slug: 'unique-slug')
        expect(variant2).not_to be_valid
        expect(variant2.errors[:slug]).to include('must be unique for this product. Please choose another slug.')
      end
    end

    describe 'status inclusion' do
      it 'accepts valid status values' do
        %w[active inactive discontinued].each do |status|
          variant = build(:product_variant, status: status)
          expect(variant).to be_valid
        end
      end

      it 'rejects invalid status values' do
        variant = build(:product_variant)
        variant.status = 'invalid'
        expect(variant).not_to be_valid
      end
    end
  end

  describe 'enums' do
    it 'defines status enum with string values' do
      expect(ProductVariant.statuses).to eq('active' => 'active', 'inactive' => 'inactive', 'discontinued' => 'discontinued')
    end
  end

  describe 'callbacks' do
    describe '#set_default_price' do
      it 'does not override existing original_price' do
        variant = build(:product_variant, original_price: 100)
        variant.valid?
        expect(variant.original_price).to eq(100)
      end
    end

    describe '#set_default_slug' do
      it 'generates slug from name when slug is blank' do
        variant = build(:product_variant, name: 'Test Variant', slug: nil)
        variant.valid?
        expect(variant.slug).to eq('test-variant')
      end

      it 'does not override existing slug' do
        variant = build(:product_variant, name: 'Test Variant', slug: 'custom-slug')
        variant.valid?
        expect(variant.slug).to eq('custom-slug')
      end
    end
  end

  describe 'attached images' do
    it 'allows multiple image attachments' do
      variant = create(:product_variant, :with_images)
      expect(variant.images.count).to eq(3)
    end

    it 'supports image attachments via ActiveStorage' do
      variant = create(:product_variant)
      variant.images.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'files', 'test_image.jpg')),
        filename: 'image.jpg',
        content_type: 'image/jpeg'
      )
      expect(variant.images).to be_attached
    end
  end

  describe '#safe_variant_attributes' do
    it 'returns dynamic JSONB attributes' do
      variant = create(:product_variant, :with_attributes)
      attributes = variant.safe_variant_attributes
      expect(attributes['color']).to eq('Red')
      expect(attributes['size']).to eq('Large')
    end

    it 'returns empty hash when no attributes set' do
      variant = create(:product_variant)
      expect(variant.safe_variant_attributes).to eq({})
    end
  end

  describe 'dynamic JSONB attributes' do
    it 'stores and retrieves custom attributes' do
      variant = create(:product_variant)
      variant.variant_attributes = { 'material' => 'Cotton', 'weight' => '500g' }
      variant.save!

      variant.reload
      expect(variant.variant_attributes['material']).to eq('Cotton')
      expect(variant.variant_attributes['weight']).to eq('500g')
    end
  end

  describe 'scopes' do
    let(:product) { create(:product) }

    describe '.active' do
      let!(:active_variant) { create(:product_variant, product: product, status: 'active') }
      let!(:inactive_variant) { create(:product_variant, product: product, status: 'inactive') }

      it 'returns only active variants' do
        expect(ProductVariant.active).to include(active_variant)
        expect(ProductVariant.active).not_to include(inactive_variant)
      end
    end

    describe '.inactive' do
      let!(:active_variant) { create(:product_variant, product: product, status: 'active') }
      let!(:inactive_variant) { create(:product_variant, product: product, status: 'inactive') }

      it 'returns only inactive variants' do
        expect(ProductVariant.inactive).to include(inactive_variant)
        expect(ProductVariant.inactive).not_to include(active_variant)
      end
    end

    describe '.discontinued' do
      let!(:active_variant) { create(:product_variant, product: product, status: 'active') }
      let!(:discontinued_variant) { create(:product_variant, product: product, status: 'discontinued') }

      it 'returns only discontinued variants' do
        expect(ProductVariant.discontinued).to include(discontinued_variant)
        expect(ProductVariant.discontinued).not_to include(active_variant)
      end
    end
  end

  describe 'price calculations' do
    context 'when current_price is set' do
      let(:variant) { create(:product_variant, original_price: 100, current_price: 80) }

      it 'shows discount' do
        expect(variant.current_price).to be < variant.original_price
      end
    end

    context 'when current_price is nil' do
      let(:variant) { create(:product_variant, :no_discount, original_price: 100) }

      it 'has no discount' do
        expect(variant.current_price).to be_nil
      end
    end
  end
end
