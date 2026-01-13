puts 'Seeding blogs...'

# Helper to create Lexical JSON from text
def text_to_lexical(text)
  {
    root: {
      children: [
        {
          type: "paragraph",
          children: [
            {
              type: "text",
              text: text,
              format: 0
            },
          ]
        },
      ],
      direction: nil,
      format: "",
      indent: 0,
      type: "root",
      version: 1
    }
  }
end

sample_categories = [
  {
    name: "Đánh giá sản phẩm",
    slug: "danh-gia-san-pham"
  },
  {
    name: "Kiến thức âm thanh",
    slug: "kien-thuc-am-thanh"
  },
  {
    name: "Sự kiện",
    slug: "su-kien"
  },
  {
    name: "Tin tức",
    slug: "tin-tuc"
  },
  {
    name: "Videos",
    slug: "videos"
  },
]

categories_created = 0
blogs_created = 0

sample_categories.each do |category_data|
  BlogCategory.find_or_create_by!(
    name: category_data[:name],
    slug: category_data[:slug]
  )
  categories_created += 1
  puts "  ✓ Created blog category '#{category_data[:name]}'"
end

sample_blogs = [
  {
    title: "Đánh giá tai nghe Sony WH-1000XM5",
    content: text_to_lexical("Sony WH-1000XM5 là một trong những tai nghe không dây tốt nhất trên thị trường hiện nay. Với công nghệ chống ồn tiên tiến, chất lượng âm thanh xuất sắc và thiết kế sang trọng, nó đã trở thành lựa chọn hàng đầu cho những người yêu thích âm nhạc."),
    category_id: BlogCategory.find_by!(slug: "danh-gia-san-pham")&.id,
    published_at: Time.current,
    status: "published",
    meta_title: "Đánh giá tai nghe Sony WH-1000XM5",
    meta_description: "Khám phá những tính năng nổi bật và trải nghiệm âm thanh tuyệt vời của Sony WH-1000XM5 trong bài đánh giá chi tiết này.",
    author_id: Admin.first.id,
    view_count: 0
  },
  *1.upto(10).map do |i|
    title = "Bài viết mẫu #{Faker::Book.unique.title}"
    {
      title:,
      content: text_to_lexical(1.upto(rand(3..5)).map { |_idx| Faker::Lorem.paragraph(sentence_count: rand(3..6)) }.join(" ")),
      category_id: BlogCategory.first.id,
      published_at: Time.current - i.days,
      status: "published",
      meta_title: "Bài viết mẫu #{i}",
      meta_description: "Mô tả ngắn gọn cho bài viết mẫu số #{i}.",
      author_id: Admin.first.id,
      view_count: 0
    }
  end,
]

sample_blogs.each do |blog_data|
  blog = Blog.find_or_create_by(slug: blog_data[:slug]) do |b|
    b.assign_attributes(blog_data)
  end
  if blog.persisted? && blog.created_at == blog.updated_at
    blogs_created += 1
    puts "  ✓ Created blog '#{blog.title}'"
  else
    puts "  • Blog '#{blog.title}' already exists"
  end
end

puts "\n" + "="*60
puts "Blogs Seeding Complete!"
puts "="*60
puts "✓ Created: #{categories_created} blog categories"
puts "✓ Created: #{blogs_created} blogs"
