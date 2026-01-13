class BlogIndexJob < ApplicationJob
  queue_as :default

  attr_reader :blog

  def perform(blog_id)
    fetch_blog(blog_id)
    return if blog.nil?

    blog_index_object = build_blog_index_object
    index.add_documents(blog_index_object.deep_transform_keys { |k| k.to_s.camelize(:lower) })
  end

  private

  def index
    MEILISEARCH_CLIENT.index('articles')
  end

  def fetch_blog(blog_id)
    @blog = Blog.find_by(id: blog_id)
    if !blog || !blog.published?
      Rails.logger.info("Blog ID #{blog_id} is not published or removed. Removing from index if exists.")
      index.delete_document(blog_id)
      @blog = nil
    end
  end

  def build_blog_index_object
    {
      id: "blog_#{blog.id}",
      title: blog.title,
      slug: blog.slug,
      featured_image_url: blog.image.attached? ? ImagePathService.new(blog.image).path : nil,
      published_at: blog.published_at&.iso8601
    }
  end
end
