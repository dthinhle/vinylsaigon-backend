# frozen_string_literal: true

module Api
  class CategoriesController < Api::BaseController
    include Pagy::Method

    rescue_from ActiveRecord::RecordNotFound, with: :handle_category_not_found

    def index
      # Prevent N+1 queries by including all necessary associations
      @categories = Category.includes(
        :parent,
        :children
      ).order(:title)

      # Filter by root categories if specified
      if params[:root_only] == 'true'
        @categories = @categories.root_categories
      end
    end

    def show
      # Prevent N+1 queries by including all necessary associations
      category = Category.includes(
        :parent,
        :children
      ).find_by!(slug: params[:slug])

      # If this is a sub-category, set @category to its parent with is_active false,
      # and ensure this category is marked as active in the children array
      if !category.is_root?
        @category = category.parent
        @active_subcategory = category
      else
        @category = category
      end
    end

    def related_products
      @cart = nil
      @cart = Cart.find_by(user_id: customer&.id, status: 'active') if customer.present?
      @cart ||= Cart.find_by(session_id: session_id, status: 'active')
      if @cart.nil?
        render json: { error: 'Cart not found' }, status: :not_found
        return
      end

      @products = Product.find(@cart.cart_items.pluck(:product_id).uniq)
      @related_products = ProductService.related_products(@products)
    end

    private

    def customer
      @customer ||= try(:current_user)
    end

    def session_id
      request.headers['X-Session-ID']
    end

    def render_no_related_products
      render json: { products: [], message: 'No related products found' }
    end

    def handle_category_not_found(exception)
      render json: { error: 'Category not found' }, status: :not_found
    end
  end
end
