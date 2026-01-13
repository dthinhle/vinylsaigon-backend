puts 'Seeding product images...'

require 'open-uri'

IMAGE_URLS = [
  "/66903/Bose-QuietComfort-Earbuds-Black-2-450x450-c.webp",
  "/66591/PDP_SF_Gallery_UOE_black2-450x450-c.webp",
  "/66577/Bose-QC-Ultra-Smoke-450x450-c.webp",
  "/66485/methodanc.3kshop11-450x450-c.webp",
  "/66246/540active.3kshop3-450x450-c.webp",
  "/66238/hd620s.3kshop3-450x450-c.webp",
  "/65768/RU9.3kshop3-450x450-c.webp",
  "/64457/1-450x450-c.webp",
  "/64315/iDSD-Valkyrie_iFiaudio-5_c877c94c-488a-43f7-9d96-76cac7766b27.png-450x450-c.webp",
  "/64266/1-3-1024x1024-1-450x450-c.webp",
  "/63473/1-450x450-c.webp",
  "/63415/2-9-450x450-c.webp",
]

FileUtils.mkdir_p(Rails.root.join("db", "seeds", "images"))

images_downloaded = 0
images_skipped = 0

IMAGE_URLS.each_with_index do |image_url, index|
  image_path = Rails.root.join("db", "seeds", "images", "image_#{index}.webp")
  puts "Processing image: #{image_path}"
  if File.exist?(image_path)
    puts "  ⚠ Skipped (already exists): image_#{index}.webp"
    images_skipped += 1
    next
  end

  begin
    File.open(image_path, 'wb') do |f|
      f.write(URI.open(
        "https://3kshop.vn/wp-content/uploads/fly-images#{image_url}",
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3"
      ).read)
    end
    images_downloaded += 1
    puts "  ✓ Downloaded: image_#{index}.webp"
  rescue => e
    puts "  ✗ Failed to download image_#{index}.webp: #{e.message}"
  end
end

puts "\n" + "="*60
puts "Product Images Seeding Complete!"
puts "="*60
puts "✓ Downloaded: #{images_downloaded} images"
puts "⚠ Skipped: #{images_skipped} (already existed)"
