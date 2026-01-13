json.extract! brand, :id, :name, :slug
json.logo_url ImagePathService.new(brand.logo).path if brand.logo.attached?
