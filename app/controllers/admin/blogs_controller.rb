class Admin::BlogsController < Admin::BaseController
  include SortableParams

  before_action :set_blog, only: %i[show edit update destroy]

  def index
    blogs = Blog.includes(:author, :category)
    blogs = BlogFilterService.new(parse_sort_by_params(params), blogs).call
    @pagy, @blogs = pagy(blogs)
  end

  def show; end

  def new
    @blog = Blog.new
  end

  def create
    params_to_create = blog_params
    params_to_create[:content] = parse_json_content(params_to_create[:content]) if params_to_create[:content].present?

    @blog = Blog.new(params_to_create)
    if @blog.save
      redirect_to admin_blog_path(@blog), notice: 'Blog was successfully created.'
    else
      flash.now[:alert] = @blog.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    params_to_update = blog_params
    params_to_update[:content] = parse_json_content(params_to_update[:content]) if params_to_update[:content].present?

    if @blog.update(params_to_update)
      redirect_to admin_blog_path(@blog), notice: 'Blog was successfully updated.'
    else
      flash.now[:alert] = @blog.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @blog.destroy
      redirect_to admin_blogs_path, notice: 'Blog was successfully deleted.'
    else
      redirect_to admin_blogs_path, alert: 'Failed to delete blog.'
    end
  end

  def destroy_selected
    ids = Array(params[:blog_ids] || params[:ids] || params[:selected_ids] || [])

    if ids.blank?
      flash[:alert] = 'No blogs selected'
      respond_to do |format|
        format.html { redirect_to admin_blogs_path }
        format.json { render json: { success: false, message: 'No ids provided' }, status: :bad_request }
      end
      return
    end

    blogs = Blog.where(id: ids)
    not_found = ids.map(&:to_i) - blogs.pluck(:id)
    failed = []

    Blog.transaction do
      blogs.each do |blog|
        failed << blog.id unless blog.destroy
      end
      raise ActiveRecord::Rollback if failed.any?
    end

    if failed.empty?
      deleted_count = blogs.size
      flash[:notice] = "#{deleted_count} blog#{'s' if deleted_count != 1} deleted"
    else
      flash[:alert] = "Failed to delete blogs: #{failed.join(', ')}"
    end

    respond_to do |format|
      format.html { redirect_to admin_blogs_path }
      format.json do
        render json: { success: failed.empty?, not_found: not_found, failed: failed },
               status: (failed.empty? ? :ok : :unprocessable_entity)
      end
    end
  end

  def upload_image
    result = ImageUploadService.call(params.permit(:file, :url))

    if result[:success]
      blob = result[:blob]
      image_url = url_for(blob)
      render json: {
        location: image_url,
        meta: {
          title: blob.filename,
          alt: blob.filename,
          dimensions: { width: blob.metadata[:width], height: blob.metadata[:height] },
          fileinput: [{ name: blob.filename, size: blob.byte_size, type: blob.content_type }]
        }
      }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  def upload_video
    result = VideoUploadService.call(params.permit(:file))

    if result[:success]
      blob = result[:blob]
      video_url = url_for(blob)
      render json: { location: video_url }
    else
      render json: { error: result[:error] }, status: :unprocessable_entity
    end
  end

  private

  def set_blog
    @blog = Blog.find(params[:id])
  end

  def blog_params
    params.require(:blog).permit(
      :title, :content, :published_at, :slug, :status,
      :meta_title, :meta_description, :category_id, :author_id,
      :view_count, :image, product_ids: []
    )
  end

  def parse_json_content(content)
    return content if content.is_a?(Hash)
    begin
      JSON.parse(content)
    rescue JSON::ParserError => e
      Rails.logger.warn("Failed to parse JSON content: #{e.message}")

      WordpressMigration::DataCleaner.clean_html(<<~HTML)
        <p>#{content}</p>
      HTML
    end
  end
end
