class Api::BlogCategoriesController < Api::BaseController
  include Pagy::Method

  def index
    @categories = BlogCategory.all.order(:name)

    render json: @categories.as_json(
      only: [:id, :name, :slug, :blogs_count]
    ), status: :ok
  end

  def show
    @category = BlogCategory.find_by(slug: params[:slug])

    raise ActiveRecord::RecordNotFound if @category.nil?
  end
end
