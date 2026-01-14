# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    allow_origins = [
       /localhost:\d{2,4}/,
      '127.0.0.1:3000',
      %r{\Ahttp://192\.168\.0\.\d{1,3}(:\d+)?\z}, # regular expressions can be used here
      FRONTEND_HOST.split('//').last,
    ]
    allow_origins << %r{\Ahttp://192\.168\.\d{1,3}\.\d{1,3}(:\d+)?\z} if Rails.env.local?
    allow_origins << /\Ahttps:\/\/vinylsaigon\.vn\z/
    allow_origins << /\Ahttps:\/\/vinylsaigon-frontend(.+)?\.vercel\.app\z/
    origins(*allow_origins)

    resource '/api/*',
      headers: :any,
      methods: :any,
      max_age: 600
  end
end
