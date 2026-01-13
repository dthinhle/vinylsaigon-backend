# frozen_string_literal: true

class Admin::RelatedCategoriesController < Admin::BaseController
  include SortableParams

  before_action :set_related_category, only: %i[show edit update destroy]

  FILTER_LABELS = {
    'q' => 'Search',
    'category_id' => 'Category',
    'weight' => 'Weight'
  }.freeze

  def index
    @filter_params = parse_sort_by_params(index_params)
    @filter_labels = FILTER_LABELS
    related_categories = RelatedCategory.includes(:category, :related_category)
    related_categories = RelatedCategoryFilterService.new(@filter_params, related_categories).call

    related_categories = related_categories.where(
      'category_id < related_category_id OR NOT EXISTS (
        SELECT 1 FROM related_categories rc2
        WHERE rc2.category_id = related_categories.related_category_id
        AND rc2.related_category_id = related_categories.category_id
      )'
    )

    @pagy, @related_categories = pagy(related_categories.order(:id))
  end

  def show; end

  def new
    @related_category = RelatedCategory.new
  end

  def create
    category = Category.find(related_category_params[:category_id])
    related_category = Category.find(related_category_params[:related_category_id])
    weight = related_category_params[:weight].to_i

    begin
      RelatedCategory.create_bidirectional!(category, related_category, weight)
      redirect_to admin_related_categories_path, notice: 'Related category relationship was successfully created.'
    rescue ActiveRecord::RecordInvalid => e
      @related_category = RelatedCategory.new(related_category_params)
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    category = Category.find(related_category_params[:category_id])
    related_category = Category.find(related_category_params[:related_category_id])
    weight = related_category_params[:weight].to_i

    begin
      RelatedCategory.update_bidirectional!(category, related_category, weight)
      redirect_to admin_related_category_path(@related_category), notice: 'Related category relationship was successfully updated.'
    rescue ActiveRecord::RecordInvalid => e
      flash.now[:alert] = e.record.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    category = @related_category.category
    related_category = @related_category.related_category

    RelatedCategory.destroy_bidirectional!(category, related_category)
    redirect_to admin_related_categories_path, notice: 'Related category relationship was successfully deleted.'
  end

  def destroy_selected
    ids = params[:related_category_ids] || params[:ids] || []

    if ids.blank?
      result = { success: false, message: 'No relationships selected.', not_found: [], failed: [] }
    else
      related_categories = RelatedCategory.includes(:category, :related_category).where(id: ids)
      found_ids = related_categories.pluck(:id).map(&:to_s)
      not_found_ids = ids - found_ids

      # Collect unique category pairs to avoid duplicate deletions
      category_pairs = related_categories.map do |rel_cat|
        [rel_cat.category_id, rel_cat.related_category_id].sort
      end.uniq

      deleted_count = 0
      failed_pairs = []

      RelatedCategory.transaction do
        category_pairs.each do |category_id, related_category_id|
          begin
            # Batch delete both directions in a single operation
            deleted_records = RelatedCategory.where(
              '(category_id = ? AND related_category_id = ?) OR (category_id = ? AND related_category_id = ?)',
              category_id, related_category_id, related_category_id, category_id
            ).delete_all

            deleted_count += 1 if deleted_records > 0
          rescue => e
            Rails.logger.error("Failed to delete relationship pair [#{category_id}, #{related_category_id}]: #{e.message}")
            failed_pairs << [category_id, related_category_id]
          end
        end
      end

      if deleted_count > 0
        result = {
          success: true,
          message: "Successfully deleted #{deleted_count} relationship pair(s) (#{deleted_count * 2} total records).",
          not_found: not_found_ids,
          failed: failed_pairs.map { |pair| "#{pair[0]}-#{pair[1]}" }
        }
      else
        result = {
          success: false,
          message: 'Failed to delete selected relationships.',
          not_found: not_found_ids,
          failed: failed_pairs.map { |pair| "#{pair[0]}-#{pair[1]}" }
        }
      end
    end

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end

    respond_to do |format|
      format.html { redirect_to admin_related_categories_path }
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

  def bulk_update_weight
    ids = params[:related_category_ids] || params[:ids] || []
    weight = params[:weight]

    if ids.blank?
      result = { success: false, message: 'No relationships selected.' }
    elsif weight.blank? || weight.to_i < 0 || weight.to_i > 10
      result = { success: false, message: 'Invalid weight value. Must be between 0 and 10.' }
    else
      related_categories = RelatedCategory.includes(:category, :related_category).where(id: ids)

      # Collect unique category pairs to avoid duplicate updates
      category_pairs = related_categories.map do |rel_cat|
        [rel_cat.category_id, rel_cat.related_category_id].sort
      end.uniq

      updated_count = 0
      failed_pairs = []

      RelatedCategory.transaction do
        category_pairs.each do |category_id, related_category_id|
          begin
            # Batch update both directions in a single operation
            updated_records = RelatedCategory.where(
              '(category_id = ? AND related_category_id = ?) OR (category_id = ? AND related_category_id = ?)',
              category_id, related_category_id, related_category_id, category_id
            ).update_all(weight: weight.to_i, updated_at: Time.current)

            updated_count += 1 if updated_records > 0
          rescue => e
            Rails.logger.error("Failed to update relationship pair [#{category_id}, #{related_category_id}]: #{e.message}")
            failed_pairs << [category_id, related_category_id]
          end
        end
      end

      if updated_count > 0
        result = {
          success: true,
          message: "Successfully updated #{updated_count} relationship pair(s) (#{updated_count * 2} total records) weight to #{weight}."
        }
      else
        result = { success: false, message: 'Failed to update selected relationships.' }
      end
    end

    if result[:success]
      flash[:notice] = result[:message]
    else
      flash[:alert] = result[:message]
    end

    respond_to do |format|
      format.html { redirect_to admin_related_categories_path }
      format.json {
        render json: {
          success: result[:success],
          message: result[:message]
        }, status: (result[:success] ? :ok : :unprocessable_entity)
      }
    end
  end

  private

  def index_params
    params.permit(
      :q,
      :category_id,
      :weight,
      :sort_by,
    )
  end

  def set_related_category
    @related_category = RelatedCategory.includes(:category, :related_category).find(params[:id])
  end

  def related_category_params
    params.require(:related_category).permit(:category_id, :related_category_id, :weight)
  end
end
