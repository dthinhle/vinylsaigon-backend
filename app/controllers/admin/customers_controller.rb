class Admin::CustomersController < Admin::BaseController
  before_action :set_customer, only: %i[show edit update destroy send_password_reset]

  FILTER_LABELS = {
    'q' => 'Search',
    'email' => 'Email',
    'disabled' => 'Status',
    'created_from' => 'Created From',
    'created_to' => 'Created To',
    'sort_by' => 'Sort'
  }.freeze

  def index
    permitted_params = index_params
    filter_params = permitted_params.to_h

    # Sanitize: Remove sort/direction if sort_by exists to avoid duplication
    if filter_params['sort_by'].present?
      filter_params.delete('sort')
      filter_params.delete('direction')
    end

    @filter_params = ActionController::Parameters.new(filter_params)
    @filter_labels = FILTER_LABELS

    customers = User.includes(:subscriber)
    customers = CustomerFilterService.new(filter_params, customers).call
    @pagy, @customers = pagy(customers)
  end

  def show
    @refresh_tokens = @customer.refresh_tokens.active.order(last_used_at: :desc)
  end

  def new
    @customer = User.new
  end

  def create
    @customer = User.new(customer_params)
    @customer.password = SecureRandom.hex(8) if @customer.password.blank?

    if @customer.save
      redirect_to admin_customer_path(@customer), notice: 'Customer was successfully created.'
    else
      flash.now[:alert] = @customer.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    customer_update_params = customer_params
    # Only update password if provided
    customer_update_params.delete(:password) if customer_update_params[:password].blank?

    if @customer.update(customer_update_params)
      redirect_to admin_customer_path(@customer), notice: 'Customer was successfully updated.'
    else
      flash.now[:alert] = @customer.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    refresh_token_id = params[:refresh_token_id]

    if refresh_token_id.present?
      begin
        refresh_token = @customer.refresh_tokens.find(refresh_token_id)
        if refresh_token.destroy
          redirect_to admin_customer_path(@customer), notice: 'Device session was successfully revoked.'
        else
          redirect_to admin_customer_path(@customer), alert: 'Failed to revoke device session.'
        end
      rescue ActiveRecord::RecordNotFound
        redirect_to admin_customer_path(@customer), alert: 'Device session not found.'
      end
    elsif @customer.destroy
      redirect_to admin_customers_path, notice: 'Customer was successfully deleted.'
    else
      redirect_to admin_customers_path, alert: 'Failed to delete customer.'
    end
  end

  def destroy_selected
    ids = params[:customer_ids] || params[:ids] || []

    if ids.blank?
      result = { success: false, message: 'No customers selected.', not_found: [], failed: [] }
    else
      customers = User.where(id: ids)
      found_ids = customers.pluck(:id).map(&:to_s)
      not_found_ids = ids - found_ids
      failed_ids = []
      deleted_count = 0

      customers.each do |customer|
        if customer.destroy
          deleted_count += 1
        else
          failed_ids << customer.id.to_s
        end
      end

      if deleted_count > 0
        result = {
          success: true,
          message: "Successfully deleted #{deleted_count} customer(s).",
          not_found: not_found_ids,
          failed: failed_ids
        }
      else
        result = {
          success: false,
          message: 'Failed to delete selected customers.',
          not_found: not_found_ids,
          failed: failed_ids
        }
      end
    end

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end

    respond_to do |format|
      format.html { redirect_to admin_customers_path }
      format.json {
        render json: {
          success: result[:success],
          message: result[:message],
          not_found: result[:not_found],
          failed: result[:failed]
        }, status: (result[:success] ? :ok : :unprocessable_entity)
      }
    end
  end

  def bulk_update_status
    ids = params[:customer_ids] || params[:ids] || []
    disabled_value = params[:disabled]

    if ids.blank?
      result = { success: false, message: 'No customers selected.' }
    elsif disabled_value.blank?
      result = { success: false, message: 'No status selected.' }
    else
      customers = User.where(id: ids)
      disabled_boolean = disabled_value == 'true'
      updated_count = customers.update_all(disabled: disabled_boolean)

      status_text = disabled_boolean ? 'Inactive' : 'Active'
      if updated_count > 0
        result = {
          success: true,
          message: "Successfully updated #{updated_count} customer(s) status to #{status_text}."
        }
      else
        result = { success: false, message: 'Failed to update selected customers.' }
      end
    end

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end

    respond_to do |format|
      format.html { redirect_to admin_customers_path }
      format.json {
        render json: {
          success: result[:success],
          message: result[:message]
        }, status: (result[:success] ? :ok : :unprocessable_entity)
      }
    end
  end

  def send_password_reset
    begin
      @customer.send_reset_password_instructions
      flash[:notice] = "Password reset email sent to #{@customer.email}"
    rescue => e
      Rails.logger.error("Failed to send password reset email: #{e.message}")
      flash[:alert] = 'Failed to send password reset email. Please try again.'
    end

    redirect_to admin_customer_path(@customer)
  end

  private

  def index_params
    params.permit(
      :q,
      :email,
      :disabled,
      :created_from,
      :created_to,
      :sort_by,
      :sort,
      :direction
    )
  end

  def set_customer
    @customer = User.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :email, :password, :name, :phone_number, :disabled
    )
  end
end
