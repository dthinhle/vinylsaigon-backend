# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProductVersionService do
  let(:admin) { create(:admin) }
  let(:product) { create(:product) }
  let(:variant) { product.product_variants.first }

  before do
    PaperTrail.request.whodunnit = admin.id.to_s
  end

  describe '.versions_for' do
    context 'when product has no versions' do
      it 'returns empty array' do
        PaperTrail::Version.where(product_id: product.id).delete_all
        expect(described_class.versions_for(product)).to eq([])
      end
    end

    context 'when product has versions' do
      before do
        PaperTrail.request.transaction_id = SecureRandom.uuid
        product.update!(name: 'Updated Name')
        variant.update!(name: 'Updated Variant')
      end

      it 'returns grouped versions by transaction_id' do
        versions = described_class.versions_for(product)
        expect(versions).to be_an(Array)
        expect(versions.first).to include(:transaction_id, :created_at, :event, :admin_email)
      end

      it 'includes admin email' do
        versions = described_class.versions_for(product)
        expect(versions.first[:admin_email]).to eq(admin.email)
      end

      it 'respects limit parameter' do
        15.times do |i|
          PaperTrail.request.transaction_id = SecureRandom.uuid
          product.update!(name: "Name #{i}")
        end

        versions = described_class.versions_for(product, limit: 5)
        expect(versions.size).to be <= 5
      end
    end
  end

  describe '.revert_to' do
    let(:original_name) { product.name }
    let(:original_variant_name) { variant.name }

    before do
      PaperTrail.request.transaction_id = SecureRandom.uuid
      product.update!(name: 'Changed Name')
      variant.update!(name: 'Changed Variant Name')
    end

    it 'reverts product to previous state' do
      transaction_id = PaperTrail::Version.where(product_id: product.id).last.transaction_id

      described_class.revert_to(product, transaction_id)
      product.reload

      expect(product.name).to eq(original_name)
    end

    it 'reverts variant to previous state' do
      transaction_id = PaperTrail::Version.where(product_id: product.id).last.transaction_id

      described_class.revert_to(product, transaction_id)
      variant.reload

      expect(variant.name).to eq(original_variant_name)
    end

    it 'raises error when transaction_id not found' do
      expect {
        described_class.revert_to(product, 'non-existent-id')
      }.to raise_error(ProductVersionService::RevertError)
    end

    it 'creates new version entries for the revert' do
      transaction_id = PaperTrail::Version.where(product_id: product.id).last.transaction_id

      expect {
        described_class.revert_to(product, transaction_id)
      }.to change { PaperTrail::Version.where(product_id: product.id).count }
    end
  end
end
