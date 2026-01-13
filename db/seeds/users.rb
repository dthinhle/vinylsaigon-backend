puts 'Seeding users...'

# Idempotent seed users for development and testing.
# Passwords are intentionally simple for local/dev use only.
# Run with: bin/rails db:seed
users = [
  {
    email: 'admin@admin.com',
    password: 'password123',
    name: 'Admin',
    phone_number: '0123456789',
    disabled: false
  },
  {
    email: 'demo@demo.com',
    password: 'password123',
    name: 'Demo User',
    phone_number: '0987654321',
    disabled: false
  },
  {
    email: 'customer@example.com',
    password: 'password123',
    name: 'Customer',
    phone_number: '0900000000',
    disabled: false
  },
]

users_created = 0

users.each do |attrs|
  user = User.find_or_create_by!(email: attrs[:email]) do |u|
    u.assign_attributes(attrs.except(:email, :password))
    u.password = attrs[:password]
  end
  if user.persisted? && user.created_at == user.updated_at
    users_created += 1
    puts "  ✓ Created user '#{attrs[:name]}' (#{attrs[:email]})"
  end
end

puts "\n" + "="*60
puts "Users Seeding Complete!"
puts "="*60
puts "✓ Created: #{users_created} users"
