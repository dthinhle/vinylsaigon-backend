# frozen_string_literal: true

class Admin::HeroBannersController < Admin::BaseController
  include SortableParams

  before_action :set_hero_banner, only: %i[show edit update destroy]

  def index
    filterable_fields = [:q, :main_title, :page, :per_page, :sort_by]
    permitted = parse_sort_by_params(params.permit(*filterable_fields))

    if defined?(HeroBannersFilterService)
      @hero_banners, @active_filters, @filter_errors, @pagy =
        HeroBannersFilterService.new(scope: HeroBanner.all, params: permitted).call

      if @pagy.nil?
        per_page = (permitted[:per_page] || 30).to_i
        @pagy, @hero_banners = pagy(@hero_banners, limit: per_page)
      end
    else
      relation = HeroBanner.order(created_at: :desc)
      per_page = (permitted[:per_page] || params[:per_page] || 30).to_i
      @pagy, @hero_banners = pagy(relation, limit: per_page)
    end

    @filters = permitted
    @selected_ids = Array(params[:selected_ids] || params[:hero_banner_ids] || params[:ids])

    respond_to do |format|
      format.html
      format.json { render json: { hero_banners: @hero_banners }, status: :ok }
    end
  end

  def show; end

  def new
    @hero_banner = HeroBanner.new
  end

  def create
    @hero_banner = HeroBanner.new(hero_banner_params.except(:images_to_remove))

    # purge any attachments requested for removal (no-op for new records)
    if params[:hero_banner] && params[:hero_banner][:images_to_remove].present?
      purge_attachments_by_ids(@hero_banner, params[:hero_banner][:images_to_remove])
    end

    respond_to do |format|
      if @hero_banner.save
        format.html { redirect_to edit_admin_hero_banner_path(@hero_banner), notice: 'Hero banner created' }
        format.turbo_stream { redirect_to edit_admin_hero_banner_path(@hero_banner), notice: 'Hero banner created', status: :see_other }
      else
        flash.now[:alert] = @hero_banner.errors.full_messages.to_sentence
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('hero_banner_form', partial: 'admin/hero_banners/form'),
            turbo_stream.replace('flash', partial: 'admins/shared/flash', locals: { flash: flash }),
          ], status: :unprocessable_entity
        end
      end
    end
  end

  def edit
  end

  def update
    respond_to do |format|
      # handle removal of images if requested
      if params[:hero_banner] && params[:hero_banner][:images_to_remove].present?
        purge_attachments_by_ids(@hero_banner, params[:hero_banner][:images_to_remove])
      end

      if @hero_banner.update(hero_banner_params.except(:images_to_remove))
        # keep UX consistent: redirect to edit on success
        format.html { redirect_to edit_admin_hero_banner_path(@hero_banner), notice: 'Hero banner updated' }
        format.turbo_stream { redirect_to edit_admin_hero_banner_path(@hero_banner), notice: 'Hero banner updated', status: :see_other }
      else
        flash.now[:alert] = @hero_banner.errors.full_messages.to_sentence
        format.html { render :edit, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace('hero_banner_form', partial: 'admin/hero_banners/form'),
          ], status: :unprocessable_entity
        end
      end
    end
  end

  def destroy
    if @hero_banner.destroy
      respond_to do |format|
        format.html { redirect_to admin_hero_banners_path, notice: 'Hero banner deleted' }
        format.turbo_stream { redirect_to admin_hero_banners_path, notice: 'Hero banner deleted', status: :see_other }
      end
    else
      respond_to do |format|
        format.html { redirect_back(fallback_location: admin_hero_banners_path, alert: 'Failed to delete hero banner.') }
        format.turbo_stream { head :unprocessable_entity }
      end
    end
  end

  # POST /admin/hero_banners/destroy_selected
  def destroy_selected
    ids = Array(params[:hero_banner_ids] || params[:ids] || params[:selected_ids] || [])
    if ids.blank?
      flash[:alert] = 'No hero banners selected'
      respond_to do |format|
        format.html { redirect_to admin_hero_banners_path }
        format.turbo_stream { redirect_to admin_hero_banners_path, status: :see_other }
        format.json { render json: { success: false, message: 'No ids provided' }, status: :bad_request }
      end
      return
    end

    banners = HeroBanner.where(id: ids)
    not_found = ids.map(&:to_i) - banners.pluck(:id)
    failed = []

    HeroBanner.transaction do
      if HeroBanner.column_names.include?('deleted_at')
        begin
          updated_count = banners.update_all(deleted_at: Time.current)
          if updated_count != banners.size
            failed = []
          end
        rescue
          failed = banners.pluck(:id)
        end
      else
        banners.each do |b|
          failed << b.id unless b.destroy
        end
      end

      raise ActiveRecord::Rollback if failed.any?
    end

    if failed.empty?
      deleted_count = banners.size
      flash[:notice] = "#{deleted_count} hero banner#{'s' if deleted_count != 1} deleted"
    else
      flash[:alert] = "Failed to delete hero banners: #{failed.join(', ')}"
    end

    respond_to do |format|
      format.html { redirect_to admin_hero_banners_path }
      format.turbo_stream { redirect_to admin_hero_banners_path, status: :see_other }
      format.json do
        render json: { success: failed.empty?, not_found: not_found, failed: failed },
               status: (failed.empty? ? :ok : :unprocessable_entity)
      end
    end
  end

  private

  def set_hero_banner
    @hero_banner = HeroBanner.find(params[:id])
  end

  def purge_attachments_by_ids(record, ids_array)
    return unless record.present? && ids_array.present?

    ids = Array(ids_array).compact.map(&:to_s)
    # currently hero banner has a single attachment called :image
    if ids.include?('image') && record.image.attached?
      record.image.purge_later
    end
  rescue => _
    # swallow errors to avoid blocking user flows; attachments will be purged asynchronously
    nil
  end

  def hero_banner_params
    params.require(:hero_banner).permit(
      :main_title,
      :description,
      :text_color,
      :url,
      :image,
      images_to_remove: []
    )
  end
end
