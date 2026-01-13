puts 'Seeding product indexing...'

CollectionGeneratorJob.perform_now
puts '  ✓ Generated product collections'

puts 'Delete all documents in Meilisearch'
MEILISEARCH_CLIENT.index('products').delete_all_documents()
puts '  ✓ Cleared Meilisearch products index'

puts 'Indexing products in Meilisearch...'
products_indexed = 0
Product.all.each do |product|
  ProductIndexJob.perform_now(product.id)
  products_indexed += 1
end
puts "  ✓ Queued #{products_indexed} products for indexing"

puts "\n" + "="*60
puts "Product Indexing Seeding Complete!"
puts "="*60
puts "✓ Products indexed: #{products_indexed}"
