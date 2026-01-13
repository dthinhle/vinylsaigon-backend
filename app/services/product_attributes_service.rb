# frozen_string_literal: true

class ProductAttributesService
  def self.upsert_attributes(product, new_attributes)
    product.product_attributes = new_attributes
    if product.save
      { status: :success, product: product }
    else
      { status: :error, errors: product.errors.full_messages }
    end
  end

  def self.update_attributes(product, updated_attributes)
    product.product_attributes = (product.product_attributes || {}).merge(updated_attributes)
    if product.save
      { status: :success, product: product }
    else
      { status: :error, errors: product.errors.full_messages }
    end
  end
end
