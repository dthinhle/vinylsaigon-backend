# frozen_string_literal: true

class Api::CollectionsController < Api::BaseController
  before_action :set_collection, only: [:show]

  def index
    @collections = ProductCollection.active
                                   .includes(:products)
                                   .where(deleted_at: nil)
                                   .order(:name)
  end

  def show
    @products = @collection.products.active.includes(
      :category,
      :product_tags,
      :product_variants
    ).order(:sort_order, :name)
  end

  private

  def set_collection
    @collection = ProductCollection.find_by!(slug: params[:slug])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Collection not found' }, status: :not_found
  end
end
