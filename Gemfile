source 'https://rubygems.org'

# Handle for ruby 3.4.1
gem 'openssl', '~> 3.3.2'
gem 'bugsnag', '~> 6.28'

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem 'rails', '~> 8.1.1'
# Use postgresql as the database for Active Record
gem 'pg', '~> 1.6'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '>= 5.0'
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder', '~> 2.14'

# Handle menu bar
gem 'acts_as_list', '~> 1.2'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache and Action Cable
gem 'solid_cache'
gem 'solid_cable'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem 'kamal', require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem 'thruster', require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem 'image_processing', '~> 1.2'

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
gem 'rack-cors'

# WordPress database connection for migration
gem 'mysql2', '~> 0.5'

# Auth
gem 'devise', '~> 4.9'
gem 'devise-jwt', '~> 0.12.1'
gem 'jwt', '~> 3.1'

# Background jobs
gem 'sidekiq', '~> 8.0'
gem 'sidekiq-scheduler', '~> 6.0'
gem 'redis', '~> 5.4'

# Search engine
gem 'meilisearch', '~> 0.32.0'

# Multi-pattern string matching using Aho-Corasick algorithm
gem 'ahocorasick'

# Request gem
gem 'httparty', '~> 0.23.2'

# Admin
gem 'rails_admin', '~> 3.0'
gem 'sassc-rails'
gem 'tailwindcss-rails'
gem 'jsbundling-rails'
gem 'pagy', '~> 43.2.6'

gem 'slugify', '~> 1.0', '>= 1.0.7'
gem 'user_agent_parser', '~> 2.20'

# Version control / Audit trail
gem 'paper_trail', '~> 17.0'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug', platforms: %i[ mri windows ], require: 'debug/prelude'
  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem 'brakeman', require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem 'rubocop-rails-omakase', require: false

  gem 'rubocop', '~> 1.81.7'
  gem 'dotenv-rails', '~> 3.2'
  gem 'capistrano', '~> 3.19.2', require: false
  gem 'capistrano-bundler', '~> 2.2', require: false
  gem 'capistrano-rails', '~> 1.7.0', require: false
  gem 'capistrano-rvm', '~> 0.1.2', require: false
  gem 'bugsnag-capistrano', require: false

  gem 'ruby-lsp', require: false
  gem 'ruby-lsp-rails', require: false
  gem 'annotaterb', '~> 4.20'
  gem 'faker'
  gem 'listen'
  gem 'letter_opener_web', '~> 3.0'
end

group :test do
  gem 'rspec-rails', '~> 8.0'
  gem 'rspec-core', '~> 3.13'
  gem 'factory_bot_rails', '~> 6.5'
  gem 'shoulda-matchers', '~> 7.0'
  gem 'database_cleaner-active_record'
  gem 'webmock'
  gem 'ruby-lsp-rspec', require: false
end

group :production do
  gem 'aws-sdk-s3', '~> 1.205'
end
