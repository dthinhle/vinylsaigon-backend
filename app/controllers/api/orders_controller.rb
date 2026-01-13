# frozen_string_literal: true

module Api
  class OrdersController < Api::BaseController
    before_action :set_order, only: [:show]
    before_action :authenticate_user_for_actions, only: [:show, :index]

    # GET /api/orders
    # List orders for current user
    def index
      service_result = Api::OrderListService.new(
        user: @user,
        params: orders_params
      ).call

      if service_result[:errors].any?
        return render json: {
          error: 'Invalid parameters',
          message: service_result[:errors].join(', ')
        }, status: :bad_request
      end

      @orders = service_result[:orders]
      @pagination = service_result[:pagination]
    rescue StandardError => e
      Rails.logger.error "[OrdersController#index] Error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        error: 'An unexpected error occurred',
        message: 'Please try again or contact support'
      }, status: :internal_server_error
    end

    # POST /api/checkout or POST /api/orders
    # Create an order from a cart
    def create
      cart = find_cart
      return render_cart_not_found unless cart

      user = current_user_for_checkout

      # Permit top-level override params and extract nested address params
      permitted_params = params.permit(:name, :email, :phone_number, :shipping_address_id, :billing_address_id, :currency, :apply_promotions,
        :idempotency_key, :installment_intent, :shipping_method, :store_address_id, :payment_method)
      shipping_address_params = extract_address_params(:shipping_address)
      billing_address_params = extract_address_params(:billing_address)

      # Call OrderCreatorService with permitted params
      @order = OrderCreatorService.call(
        cart: cart,
        user: user,
        shipping_address_params: shipping_address_params,
        billing_address_params: billing_address_params,
        apply_promotions: permitted_params.fetch(:apply_promotions, true),
        **permitted_params.slice(:name, :email, :phone_number, :shipping_address_id, :billing_address_id, :currency,
          :idempotency_key, :shipping_method, :store_address_id, :payment_method).to_h.symbolize_keys
      )

      # Set up installment payment if requested
      if permitted_params[:installment_intent]
        # Validate minimum amount for installments (3 million VND)
        if @order.total_vnd < 3_000_000
          return render json: {
            error: 'Validation failed',
            message: 'Thanh toán trả góp yêu cầu giá trị đơn hàng tối thiểu là 3.000.000 VND'
          }, status: :unprocessable_entity
        end

        @order.update!(metadata: @order.metadata.merge({ 'payment_method' => 'installment' }))
      end

      if [Order::ORDER_PAYMENT_METHODS[:ONEPAY], Order::ORDER_PAYMENT_METHODS[:INSTALLMENT]].include?(params[:payment_method])
        # Generate payment URL for the newly created order.
        # In production, always use the real OnePay gateway.
        payment_url, merch_txn_ref = OnePayService.generate_payment_url(order: @order, ip_address: request.remote_ip)
        # Enqueue the first reconciliation check: start polling after 5 minutes (attempt 1)
        OnePayQueryJob.set(wait: 5.minutes).perform_later(@order.id, merch_txn_ref, 1)
      end

      # Return the order details and the payment URL to the frontend.
      render json: { order: @order, onepay_payment_url: payment_url }, status: :created
    rescue OrderCreatorService::EmptyCartError => e
      render json: {
        error: 'Validation failed',
        message: e.message
      }, status: :unprocessable_entity
    rescue OrderCreatorService::InvalidAddressError => e
      render json: {
        error: 'Validation failed',
        message: e.message
      }, status: :unprocessable_entity
    rescue OrderCreatorService::AlreadyCheckedOutError => e
      # Extract order reference from error message if available
      order_number_match = e.message.match(/Order: (.+)/)
      order_reference = if order_number_match
                          existing_order = Order.find_by(order_number: order_number_match[1])
                          {
                            id: existing_order&.id,
                            order_number: order_number_match[1]
                          }
      end

      render json: {
        error: 'Already checked out',
        message: e.message,
        order: order_reference
      }.compact, status: :conflict
    rescue ActiveRecord::RecordInvalid => e
      render json: {
        error: 'Validation failed',
        message: e.message,
        details: e.record.errors.full_messages
      }, status: :unprocessable_entity
    rescue ArgumentError => e
      render json: {
        error: 'Invalid parameters',
        message: e.message
      }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "[OrdersController] Unexpected error: #{e.class} - #{e.message}\n#{e.backtrace.join("\n")}"
      render json: {
        error: 'An unexpected error occurred',
        message: 'Please try again or contact support'
      }, status: :internal_server_error
    end

    # GET /api/orders/:id
    # Get order details
    def show
      # Authorization already handled by before_action
      render :show, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: 'Not found',
        message: 'Order not found'
      }, status: :not_found
    end

    def search_by_number
      set_order_by_number
      render :show, status: :ok
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: 'Not found',
        message: 'Không tìm thấy đơn hàng. Hãy kiểm tra lại email và mã đơn hàng của bạn.'
      }, status: :not_found
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: {
        error: 'Bad request',
        message: e.message
      }, status: :bad_request
    end

    private

    # Find cart by cart_id or session_id
    def find_cart
      if params[:cart_id].present?
        Cart.find_by(id: params[:cart_id])
      elsif session_id.present?
        Cart.find_by(session_id: session_id)
      end
    end

    # Get current user for checkout (optional for guest checkout)
    def current_user_for_checkout
      # Try to get user from JWT token if present
      begin
        authenticate_user! if request.authorization.present?
        @user
      rescue ::Error::AuthorizationError
        # Guest checkout allowed, no user required
        nil
      end
    end

    # Get session ID from header
    def session_id
      request.headers['X-Session-ID']
    end

    # Extract address parameters from nested params
    def extract_address_params(address_type)
      return nil unless params[address_type].present?

      params.require(address_type).permit(
        :name,
        :phone_number,
        :line1,
        :line2,
        :address,
        :city,
        :state,
        :district,
        :ward,
        :postal_code,
        :country
      )
    end

    # Set order for show action
    def set_order
      # The :id parameter can be either the order's UUID or its public order_number
      @order = Order.find_by(id: params[:id]) || Order.find_by!(order_number: params[:id])
    end

    def authenticate_user_for_actions
      # For order retrieval, user must be authenticated
      authenticate_user!

      # Skip authorization check for index action (user can only see their own orders)
      return if action_name == 'index'

      # Check if user owns the order or is admin
      unless order_belongs_to_user?(@order) || user_is_admin?
        render json: {
          error: 'Forbidden',
          message: 'You do not have permission to access this order'
        }, status: :forbidden
      end
    rescue ::Error::AuthorizationError
      render json: {
        error: 'Unauthorized',
        message: 'Authentication required'
      }, status: :unauthorized
    end

    # Check if order belongs to current user
    def order_belongs_to_user?(order)
      return false unless @user.present?

      order.user_id == @user.id
    end

    # Check if user is admin (placeholder - implement based on your auth system)
    def user_is_admin?
      # TODO: Implement admin check based on your authorization system
      # For example: @user.admin? or @user.has_role?(:admin)
      false
    end

    # Render cart not found error
    def render_cart_not_found
      render json: {
        error: 'Not found',
        message: 'Cart not found. Please provide a valid cart_id or session_id'
      }, status: :not_found
    end

    def set_order_by_number
      email = params[:email]&.strip&.downcase
      order_number = params[:order_number]&.strip

      raise ArgumentError, 'Vui lòng nhập Email' if email.blank?
      raise ArgumentError, 'Vui lòng nhập Mã đơn hàng' if order_number.blank?

      @order = Order.where(order_number: order_number)
        .where('LOWER(email) = ?', email.downcase)
        .first

      raise ActiveRecord::RecordNotFound if @order.nil?
    end

    def orders_params
      params.permit(:status, :payment_status, :search, :period, :from_date, :to_date, :page, :per_page)
    end
  end
end
