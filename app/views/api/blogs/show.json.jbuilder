json.partial! 'blog_info', locals: { blog: @blog }

if @blog.products.any?
  json.products do
    json.array! @blog.products do |product|
      json.extract! product, :id, :name, :status, :slug, :description, :created_at, :updated_at

      json.current_price product.current_price&.to_f || product.original_price&.to_f
      json.flags product.formatted_flags

      json.seo do
        json.title product.meta_title
        json.description product.meta_description
      end

      json.brands product.brands.pluck(:name)

      json.categories { }

      json.collections product.product_collections.pluck(:name)
      json.tags product.product_tags

      json.related_products { }

      json.variants product.product_variants.displayable.map do |variant|
        json.extract! variant, :name, :slug, :short_description, :original_price, :variant_attributes
        json.status variant.status
        json.current_price variant.current_price&.to_f || variant.original_price&.to_f
        json.images variant.images.map { |img| ImagePathService.new(img).path }
      end
    end
  end
else
  json.products []
end

json.next_post do |next_post|
   @blog.next_post ? json.extract!(@blog.next_post, :title, :slug) : nil
end
json.previous_post do |previous_post|
   @blog.previous_post ? json.extract!(@blog.previous_post, :title, :slug) : nil
end
