# frozen_string_literal: true

class Admin::SystemConfigsController < Admin::BaseController
  include SortableParams

  before_action :set_system_config, only: %i[show edit update]

  def index
    permitted = parse_sort_by_params(params.permit(:page, :per_page, :sort, :direction, :sort_by, q: [:name, :value, :sort, :direction]))
    q = permitted[:q] || {}

    relation = SystemConfig.all
    relation = SystemConfigsFilterService.new(scope: relation, params: permitted).call

    per_page = (q[:per_page] || permitted[:per_page] || params[:per_page] || 30).to_i
    @pagy, @system_configs = pagy(relation, limit: per_page)

    @filters = permitted
    respond_to do |format|
      format.html
      format.json { render json: { system_configs: @system_configs }, status: :ok }
    end
  end

  def show; end

  def create
    @system_config = SystemConfig.new(system_config_params)

    respond_to do |format|
      if @system_config.save
        format.html { redirect_to admin_system_configs_path, notice: 'System config created' }
        format.turbo_stream { redirect_to admin_system_configs_path, notice: 'System config created', status: :see_other }
      else
        flash.now[:alert] = @system_config.errors.full_messages.to_sentence
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('system_config_form', partial: 'admin/system_configs/form'),
            turbo_stream.replace('flash', partial: 'admins/shared/flash', locals: { flash: flash }),
          ], status: :unprocessable_entity
        end
      end
    end
  end

  def edit; end

  def update
    respond_to do |format|
      if @system_config.update(system_config_params)
        format.html { redirect_to admin_system_configs_path, notice: 'System config updated' }
        format.turbo_stream { redirect_to admin_system_configs_path, notice: 'System config updated', status: :see_other }
      else
        flash.now[:alert] = @system_config.errors.full_messages.to_sentence
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('system_config_form', partial: 'admin/system_configs/form'),
          ], status: :unprocessable_entity
        end
      end
    end
  end

  private

  def set_system_config
    @system_config = SystemConfig.find(params[:id])
  end

  def system_config_params
    params.require(:system_config).permit(:name, :value)
  end
end
