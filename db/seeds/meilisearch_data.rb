puts 'Seeding Meilisearch indexes...'

return unless MEILISEARCH_CLIENT.healthy?

require 'csv'

PRODUCT_INDEX_DATA = {
  name: 'products',
  filterable_attrs: [
    'name',
    'currentPrice',
    'originalPrice',
    'categories',
    'brands',
    'tags',
    'collections',
    'flags',
  ],
  sortable_attributes: [
    'name',
    'currentPrice',
    'originalPrice',
    'createdAt',
    'updatedAt',
  ]
}
ARTICLE_INDEX_DATA = {
  name: 'articles',
  filterable_attrs: [
    'title',
  ],
  sortable_attributes: [
    'title',
    'published_at',
  ]
}

indexes_created = 0
indexes_updated = 0

[
  PRODUCT_INDEX_DATA,
  ARTICLE_INDEX_DATA,
].each do |data|
  name, filter_attrs, sort_attrs = data.values_at(:name, :filterable_attrs, :sortable_attributes)
  puts "Creating index: #{name}"
  client = MEILISEARCH_CLIENT
  begin
    client.fetch_index(name)
    puts "  ✓ Index '#{name}' already exists"
  rescue Meilisearch::ApiError => _e
    client.create_index(name, primary_key: 'id')
    indexes_created += 1
    sleep 2
  end
  index = client.index(name)

  if index.filterable_attributes != filter_attrs
    index.update_filterable_attributes(filter_attrs)
    indexes_updated += 1
    puts "  ✓ Updated filterable attributes for #{name}"
  end

  if index.sortable_attributes != sort_attrs
    index.update_sortable_attributes(sort_attrs)
    indexes_updated += 1
    puts "  ✓ Updated sortable attributes for #{name}"
  end
end

puts "\n" + "="*60
puts "Meilisearch Indexes Seeding Complete!"
puts "="*60
puts "✓ Created: #{indexes_created} new indexes"
puts "✓ Updated: #{indexes_updated} index configurations"

article_data = CSV.read('db/seeds/meilisearch_articles.csv', headers: true)
article_documents = article_data.map do |row|
  row = row.to_h
  row['published_at'] = Time.at(row['published_at'].to_i)

  row
end


blog_documents = Blog.published.map do |blog|
  {
    id: blog.id,
    title: blog.title,
    status: blog.status,
    slug: blog.slug,
    content: blog.content_text,
    publishedAt: blog.published_at&.iso8601,
    createdAt: blog.created_at.iso8601,
    updatedAt: blog.updated_at.iso8601,
    authorId: blog.author_id,
    categoryId: blog.category_id,
    viewCount: blog.view_count
  }
end

MEILISEARCH_CLIENT.index('articles').delete_all_documents
MEILISEARCH_CLIENT.index('articles').add_documents(blog_documents) if blog_documents.any?
