# frozen_string_literal: true

class Admin::PromotionsController < Admin::BaseController
  include SortableParams

  before_action :set_promotion, only: [:show, :edit, :update, :destroy]

  FILTERABLE_FIELDS = [
    :q, :title, :code,
    :starts_after, :starts_before, :ends_after, :ends_before,
    :starts_at_from, :starts_at_to, :ends_at_from, :ends_at_to,
    :active, :page, :per_page, :sort_by,
  ].freeze

  FILTER_LABELS = {
    'q' => 'Search',
    'title' => 'Title',
    'code' => 'Code',
    'starts_after' => 'Starts After',
    'starts_before' => 'Starts Before',
    'ends_after' => 'Ends After',
    'ends_before' => 'Ends Before',
    'starts_at_from' => 'Starts From',
    'starts_at_to' => 'Starts To',
    'ends_at_from' => 'Ends From',
    'ends_at_to' => 'Ends To',
    'active' => 'Active',
    'sort' => 'Sort',
    'direction' => 'Direction',
    'sort_by' => 'Sort By'
  }.freeze

  def index
    @filter_params = parse_sort_by_params(index_params)
    @filter_labels = FILTER_LABELS

    @promotions, @active_filters, @filter_errors, @pagy =
      PromotionFilterService.new(scope: Promotion.all, params: @filter_params, request: request).call

    @selected_ids = Array(params[:selected_ids] || params[:promotion_ids] || params[:ids])

    respond_to do |format|
      format.html { render :index }
      format.json { render json: { promotions: @promotions.as_json(except: [:metadata]) }, status: :ok }
    end
  end

  def show
  end

  def new
    @promotion = Promotion.new
    @promotion.product_bundles.build
    @promotion.product_bundles.build
  end

  def create
    @promotion = Promotion.new(promotion_params)

    respond_to do |format|
      if @promotion.save
        format.html { redirect_to admin_promotions_path, notice: 'Promotion created' }
        format.turbo_stream { redirect_to admin_promotions_path, notice: 'Promotion created', status: :see_other }
      else
        flash.now[:alert] = @promotion.errors.full_messages.to_sentence
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('promotion_form', partial: 'admin/promotions/form'),
            turbo_stream.replace('flash', partial: 'admins/shared/flash', locals: { flash: flash }),
          ], status: :unprocessable_entity
        end
      end
    end
  end

  def edit
    respond_to do |format|
      format.html
      format.turbo_stream { render :edit, formats: :html }
    end
  end

  def update
    respond_to do |format|
      if @promotion.update(promotion_params)
        format.html { redirect_to admin_promotions_path, notice: 'Promotion updated' }
        format.turbo_stream { redirect_to admin_promotions_path, notice: 'Promotion updated', status: :see_other }
      else
        flash.now[:alert] = @promotion.errors.full_messages.to_sentence
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('promotion_form', partial: 'admin/promotions/form'),
          ], status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    # Using hard destroy here for now; consider soft-delete (set deleted_at) if required.
    if @promotion.destroy
      respond_to do |format|
        format.html { redirect_to admin_promotions_path, notice: 'Promotion deleted' }
        format.turbo_stream { redirect_to admin_promotions_path, notice: 'Promotion deleted', status: :see_other }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: admin_promotions_path, alert: 'Failed to delete promotion.') }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end

  # POST /admin/promotions/destroy_selected
  def destroy_selected
    ids = Array(params[:promotion_ids] || params[:ids] || params[:selected_ids] || [])
    promotions = Promotion.where(id: ids)
    not_found = ids.map(&:to_i) - promotions.pluck(:id)
    failed = []

    Promotion.transaction do
      promotions.each do |p|
        failed << p.id unless p.destroy
      end
      # rollback if any failed to ensure atomicity
      raise ActiveRecord::Rollback if failed.any?
    end

    if failed.empty?
      flash[:notice] = 'Promotions deleted'
    else
      flash[:alert] = "Failed to delete promotions: #{failed.join(', ')}"
    end

    respond_to do |format|
      format.html { redirect_to admin_promotions_path }
      format.turbo_stream { redirect_to admin_promotions_path, status: :see_other }
      format.json do
        render json: { success: failed.empty?, not_found: not_found, failed: failed },
               status: (failed.empty? ? :ok : :unprocessable_entity)
      end
    end
  end

  private

  def set_promotion
    @promotion = Promotion.find(params[:id])
  end

  def index_params
    params.permit(*FILTERABLE_FIELDS)
  end

  def promotion_params
    params.require(:promotion).permit(
      :title,
      :code,
      :starts_at,
      :ends_at,
      :discount_type,
      :discount_value,
      :active,
      :usage_limit,
      :stackable,
      :max_discount_amount_vnd,
      product_bundles_attributes: [:id, :product_id, :product_variant_id, :quantity, :_destroy]
    )
  end
end
