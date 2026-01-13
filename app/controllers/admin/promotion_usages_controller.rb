# frozen_string_literal: true

class Admin::PromotionUsagesController < Admin::BaseController
  include SortableParams

  helper Admin::PromotionsHelper
  before_action :set_promotion, if: -> { params[:promotion_id].present? }
  before_action :set_usage, only: [:show]

  FILTER_LABELS = {
    'promotion_code' => 'Promotion',
    'user_email' => 'User Email',
    'active' => 'Active',
    'sort_by' => 'Sort',
    'per_page' => 'Per Page'
  }.freeze

  def index
    permitted = parse_sort_by_params(index_params)

    scope = PromotionUsagesFilterService
              .new(scope: PromotionUsage.all, params: permitted, promotion: @promotion)
              .call

    @pagy, @usages = pagy(scope, limit: (permitted[:per_page] || 20))

    @filter_params = index_params
    @filter_labels = FILTER_LABELS

    respond_to do |format|
      format.html
      format.json { render json: { promotion_usages: @usages }, status: :ok }
    end
  end

  # GET /admin/promotions/:promotion_id/promotion_usages/:id
  def show
  end

  # NOTE: Revoke feature removed. Any previous revoke behavior is deprecated.

  private

  def index_params
    params.permit(
      :active,
      :page,
      :per_page,
      :promotion_id,
      :sort_by,
      :user_email,
      :promotion_code
    )
  end

  def set_promotion
    @promotion = Promotion.find(params[:promotion_id])
  end

  def set_usage
    if @promotion
      @usage = @promotion.promotion_usages.find(params[:id])
    else
      @usage = PromotionUsage.find(params[:id])
    end
  end
end
