class Admin::AdminsController < Admin::BaseController
  before_action :set_admin, only: %i[edit update destroy send_password_reset]
  before_action :prevent_self_deletion, only: %i[destroy]

  FILTER_LABELS = {
    'q' => 'Search',
    'email' => 'Email',
    'name' => 'Name',
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

    admins = Admin.all
    admins = AdminFilterService.new(filter_params, admins).call
    @pagy, @admins = pagy(admins, limit: 25)
  end

  def new
    @admin = Admin.new
  end

  def create
    begin
      @admin = AdminCreatorService.call(admin_params: admin_params)
      redirect_to admin_admins_path, notice: "Admin was successfully created. Welcome email sent to #{@admin.email}."
    rescue AdminCreatorService::InvalidAdminDataError => e
      @admin = Admin.new(admin_params)
      flash.now[:alert] = e.message
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    begin
      AdminUpdaterService.call(admin: @admin, admin_params: admin_params, current_admin: current_admin)
      redirect_to admin_admins_path, notice: 'Admin was successfully updated.'
    rescue AdminUpdaterService::EmailConfirmationMismatchError, AdminUpdaterService::InvalidAdminDataError => e
      flash.now[:alert] = e.message
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @admin.destroy
      redirect_to admin_admins_path, notice: 'Admin was successfully deleted.'
    else
      redirect_to admin_admins_path, alert: 'Failed to delete admin.'
    end
  end

  def send_password_reset
    begin
      @admin.send_reset_password_instructions
      message = "Password reset email sent to #{@admin.email}"

      respond_to do |format|
        format.html do
          flash[:notice] = message
          redirect_to edit_admin_admin_path(@admin)
        end
        format.json { render json: { success: true, message: message }, status: :ok }
      end
    rescue StandardError => e
      Rails.logger.error("Failed to send password reset email: #{e.message}")
      error_message = 'Failed to send password reset email. Please try again.'

      respond_to do |format|
        format.html do
          flash[:alert] = error_message
          redirect_to edit_admin_admin_path(@admin)
        end
        format.json { render json: { success: false, message: error_message }, status: :unprocessable_entity }
      end
    end
  end

  private

  def index_params
    params.permit(
      :q,
      :email,
      :name,
      :created_from,
      :created_to,
      :sort_by,
    )
  end

  def set_admin
    @admin = Admin.find(params[:id])
  end

  def prevent_self_deletion
    if @admin.id == current_admin.id
      redirect_to admin_admins_path, alert: 'You cannot delete your own admin account.'
    end
  end

  def admin_params
    params.require(:admin).permit(:name, :email, :email_confirmation, :order_notify)
  end
end
