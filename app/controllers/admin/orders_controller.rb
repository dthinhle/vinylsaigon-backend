# frozen_string_literal: true

class Admin::OrdersController < Admin::BaseController
  include SortableParams

  before_action :set_order, only: [:show, :update_status]

  FILTER_LABELS = {
    'q' => 'Search',
    'order_number' => 'Order Number',
    'status' => 'Status',
    'customer_email' => 'Customer Email',
    'contains_free_installment' => 'Contains Free Installment',
    'installment_only' => 'Installment Payment',
    'fully_free_installment' => 'Fully Free Installment',
    'from_date' => 'From Date',
    'to_date' => 'To Date',
    'sort_by' => 'Sort'
  }.freeze

  def index
    permitted = parse_sort_by_params(index_params)

    @orders, @active_filters, @filter_errors, @pagy =
      OrderFilterService.new(scope: Order.includes(:user, :order_items), params: permitted, request: request).call

    @filter_params = index_params
    @filter_labels = FILTER_LABELS

    @status_counts = {
      all: Order.count,
      awaiting_payment: Order.status_awaiting_payment.count,
      paid: Order.status_paid.count,
      fulfilled: Order.status_fulfilled.count,
      canceled: Order.status_canceled.count,
      refunded: Order.status_refunded.count,
      failed: Order.status_failed.count
    }

    respond_to do |format|
      format.html { render :index }
      format.json { render json: { orders: @orders }, status: :ok }
    end
  end

  # GET /admin/orders/:id
  def show
    @order = Order.includes(:user, :order_items, :billing_address, :shipping_address).find(params[:id])
  end

  # PATCH /admin/orders/:id/update_status
  def update_status
    new_status = params[:status]

    unless Order.statuses.key?(new_status)
      flash[:alert] = "Invalid status: #{new_status}"
      redirect_to admin_order_path(@order) and return
    end

    # Validate status transitions
    valid_transition = case @order.status
    when 'awaiting_payment'
      valid_statuses = %w[paid canceled]
      valid_statuses << 'fulfilled' if @order.payment_method == 'cod'
      valid_statuses.include?(new_status)
    when 'paid'
      %w[fulfilled refunded canceled].include?(new_status)
    when 'fulfilled'
      %w[refunded].include?(new_status)
    else
      false
    end

    unless valid_transition
      flash[:alert] = "Invalid status transition from #{@order.status} to #{new_status}"
      redirect_to admin_order_path(@order) and return
    end

    # Log status change in metadata
    metadata = @order.metadata || {}
    metadata['status_history'] ||= []
    metadata['status_history'] << {
      'from' => @order.status,
      'to' => new_status,
      'changed_at' => Time.current.iso8601,
      'changed_by' => current_admin.email
    }

    if @order.update(status: new_status, metadata: metadata)
      flash[:notice] = "Order status updated to #{new_status.humanize}"
    else
      flash[:alert] = "Failed to update order status: #{@order.errors.full_messages.to_sentence}"
    end

    redirect_to admin_order_path(@order)
  end

  # GET /admin/orders/export (placeholder)
  def export
    # TODO: Implement CSV export functionality
    flash[:notice] = 'Export feature coming soon'
    redirect_to admin_orders_path
  end

  private

  def index_params
    params.permit(
      :q,
      :order_number,
      :status,
      :customer_email,
      :email,
      :phone_number,
      :name,
      :promotion_code,
      :contains_free_installment,
      :installment_only,
      :fully_free_installment,
      :from_date,
      :to_date,
      :page,
      :per_page,
      :sort_by
    )
  end

  def set_order
    @order = Order.find(params[:id])
  end
end
