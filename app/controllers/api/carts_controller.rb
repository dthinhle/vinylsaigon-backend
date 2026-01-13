module Api
  class CartsController < Api::BaseController
    before_action :authenticate_user
    before_action :require_session_id
    before_action :set_cart, only: [:show, :update, :destroy, :update_guest_email]

    def index
      @cart = CartService.find_or_create_cart(build_cart_params)
    end

    def show
    end

    def create
      @cart = CartService.find_or_create_cart(build_cart_params)
      render status: :created
    end

    def update
      @cart.update!(cart_params)
    end

    def update_guest_email
      unless params[:email]
        render json: { error: 'Email is required' }, status: :unprocessable_entity and return
      end
      @cart.update!(guest_email: params[:email])
    end

    def destroy
      @cart.update!(status: 'abandoned')
      head :no_content
    end

    def add_item
      result = CartService.add_item_to_cart(
        build_cart_params,
        params[:product_id],
        params[:quantity].to_i,
        params[:product_variant_id]
      )

      @cart = result[:cart_item].cart
      @auto_apply_error = result[:auto_apply_error]
      render status: :created
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    rescue StandardError => e
      Rails.logger.error("Unexpected error in add_item: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def add_bundle
      unless params[:promotion_id].present?
        render json: { error: 'Promotion is required' }, status: :bad_request
        return
      end

      result = CartService.add_bundle_to_cart(
        build_cart_params,
        params[:promotion_id]
      )

      @cart = result[:cart]
      @auto_apply_error = result[:auto_apply_error]
      render :show, status: :created
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("Unexpected error in add_bundle: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def update_item
      result = CartService.update_item_quantity(
        build_cart_params,
        params[:item_id],
        params[:quantity].to_i
      )

      @cart = CartService.find_or_create_cart(build_cart_params)
      @cart_item = result[:cart_item]
      @auto_apply_error = result[:auto_apply_error]
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    rescue StandardError => e
      render json: { error: e.message }, status: :unprocessable_entity
    end

    def remove_item
      result = CartService.remove_item(build_cart_params, params[:item_id])
      @cart = result[:cart]
      @auto_apply_error = result[:auto_apply_error]
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    end

    def apply_promotion
      @cart = CartService.find_or_create_cart(build_cart_params)
      codes = params.require(:promotion_codes)

      @cart.promotions.clear
      @cart.reload

      error_codes = []
      ActiveRecord::Base.transaction do
        codes.each do |code|
          result = ApplyPromotionCodeService.new(redeemable: @cart, code: code, user: customer).call
          if !result.success?
            error_codes << result.error_code
            raise ActiveRecord::Rollback
          end
        end
      end

      if error_codes.empty?
        render :show, status: :ok
      else
        @cart.reload
        render json: { error_codes: error_codes }, status: :unprocessable_entity
      end
    end

    def claim
      unless current_user
        render json: { error: 'Authentication required' }, status: :unauthorized
        return
      end

      @cart = CartService.find_or_create_cart(build_cart_params)
    end

    def email
      @emailed_cart = CartService.email_cart(
        build_cart_params,
        params[:email],
        create_account_prompt: params[:create_account_prompt]
      )
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("Unexpected error in email: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: 'An unexpected error occurred.' }, status: :internal_server_error
    end

    def shared
      @cart = CartService.get_shared_cart(params[:access_token])
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Cart not found or link expired' }, status: :not_found
    end

    def merge
      shared_cart = EmailedCart.find_by!(access_token: params[:access_token]).cart
      raise Error::EmptyCartError, 'Shared cart is empty' if shared_cart.cart_items.empty?

      current_cart = CartService.find_or_create_cart(build_cart_params)

      result = CartService.merge_carts(current_cart, shared_cart)
      @cart = result[:cart]
      @auto_apply_error = result[:auto_apply_error]
      render :show, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Shared cart not found' }, status: :not_found
    rescue Error::EmptyCartError => e
      render json: { error: e.message }, status: :no_content
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      Rails.logger.error("Unexpected error in merge: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}")
      render json: { error: 'An unexpected error occurred while merging carts.' }, status: :internal_server_error
    end

    private

    def customer
      try(:current_user) || @user
    end

    def require_session_id
      unless session_id.present?
        render json: { error: 'Session ID required in X-Session-ID header' }, status: :bad_request
      end
    end

    def session_id
      request.headers['X-Session-ID']
    end

    def build_cart_params
      { session_id: session_id, user_id: customer&.id }
    end

    def set_cart
      @cart = CartService.find_or_create_cart(build_cart_params)
    end

    def cart_params
      params.require(:cart).permit(:guest_email, metadata: {})
    end
  end
end
