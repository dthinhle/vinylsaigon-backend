require 'rails_helper'

RSpec.describe BundlePromotionEvaluator do
  let(:cart) { create(:cart) }
  let(:product_a) { create(:product) }
  let(:product_b) { create(:product) }
  let(:variant_a) { create(:product_variant, product: product_a) }
  let(:variant_b) { create(:product_variant, product: product_b) }

  describe '#applicable?' do
    context 'with bundle promotion matching cart items' do
      let(:promotion) do
        create(:promotion, discount_type: 'bundle', discount_value: 500000)
      end

      before do
        create(:product_bundle, promotion: promotion, product: product_a, quantity: 1)
        create(:product_bundle, promotion: promotion, product: product_b, quantity: 1)

        create(:cart_item, cart: cart, product: product_a, product_variant: variant_a, quantity: 1)
        create(:cart_item, cart: cart, product: product_b, product_variant: variant_b, quantity: 1)
      end

      it 'returns true when all bundle requirements are met' do
        evaluator = described_class.new(cart, promotion)
        expect(evaluator.applicable?).to be true
      end

      it 'calculates correct number of complete sets' do
        evaluator = described_class.new(cart, promotion)
        expect(evaluator.complete_sets_count).to eq(1)
      end

      it 'calculates correct discount amount' do
        evaluator = described_class.new(cart, promotion)
        expect(evaluator.total_discount).to eq(500000)
      end
    end

    context 'with multiple sets in cart' do
      let(:promotion) do
        create(:promotion, discount_type: 'bundle', discount_value: 500000)
      end

      before do
        create(:product_bundle, promotion: promotion, product: product_a, quantity: 1)
        create(:product_bundle, promotion: promotion, product: product_b, quantity: 1)

        create(:cart_item, cart: cart, product: product_a, product_variant: variant_a, quantity: 2)
        create(:cart_item, cart: cart, product: product_b, product_variant: variant_b, quantity: 3)
      end

      it 'calculates correct number of complete sets' do
        evaluator = described_class.new(cart, promotion)
        expect(evaluator.complete_sets_count).to eq(2)
      end

      it 'applies discount per set' do
        evaluator = described_class.new(cart, promotion)
        expect(evaluator.total_discount).to eq(1000000)
      end
    end

    context 'with partial bundle in cart' do
      let(:promotion) do
        create(:promotion, discount_type: 'bundle', discount_value: 500000)
      end

      before do
        create(:product_bundle, promotion: promotion, product: product_a, quantity: 1)
        create(:product_bundle, promotion: promotion, product: product_b, quantity: 1)

        create(:cart_item, cart: cart, product: product_a, product_variant: variant_a, quantity: 1)
      end

      it 'returns false when bundle requirements are not met' do
        evaluator = described_class.new(cart, promotion)
        expect(evaluator.applicable?).to be false
      end

      it 'returns zero discount' do
        evaluator = described_class.new(cart, promotion)
        expect(evaluator.total_discount).to eq(0)
      end
    end
  end
end
