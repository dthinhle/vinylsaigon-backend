json.banners @banners do |banner|
  json.partial! 'models/hero_banner', banner: banner
end

json.root_categories @categories do |category|
  json.partial! 'models/category', category: category
end
