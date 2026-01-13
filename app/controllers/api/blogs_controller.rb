# frozen_string_literal: true

module Api
  class BlogsController < Api::BaseController
    include Pagy::Method

    # Current fixed 5 categories
    CATEGORY_LIMIT = 5

    def index
      blogs = Blog.includes(:author, :category).published.order(published_at: :desc)

      if params[:category].present?
        blogs = blogs.joins(:category).where(blog_categories: { slug: params[:category] })
      end

      @pagy, @blogs = pagy(blogs, page: params[:page] || 1, limit: params[:per_page] || 9)
    end

    def show
      @blog = Blog.published.includes(:author, :category, products: [:brands, :product_collections, :product_variants]).find_by(slug: params[:slug])
      if @blog
        # Only increment view count for non-prefetch requests
        unless request.headers['HTTP_PURPOSE'] == 'prefetch'
          @blog.increment!(:view_count)
        end
      else
        render json: { error: 'Blog not found' }, status: :not_found
      end
    end

    def view_count
      @blog = Blog.published.find_by(slug: params[:slug])
      if @blog
        @blog.increment!(:view_count)
        render json: { view_count: @blog.view_count }
      else
        render json: { error: 'Blog not found' }, status: :not_found
      end
    end

    def categories
      @categories = BlogCategory.all.limit(CATEGORY_LIMIT)
    end

    private

    def blog_params
      params.require(:blog).permit(:title, :content, :category_id, :author_id, :published_at, :status)
    end
  end
end
