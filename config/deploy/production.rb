# server-based syntax
# ======================
# Defines a single server with a list of roles and multiple properties.
# You can define all roles on a single server, or split them:

# server "example.com", user: "deploy", roles: %w{app db web}, my_property: :my_value
# server "example.com", user: "deploy", roles: %w{app web}, other_property: :other_value
# server "db.example.com", user: "deploy", roles: %w{db}



# role-based syntax
# ==================

# Defines a role with one or multiple servers. The primary server in each
# group is considered to be the first unless any hosts have the primary
# property set. Specify the username and a domain or IP for the server.
# Don't use `:all`, it's a meta role.

# role :app, %w{deploy@example.com}, my_property: :my_value
# role :web, %w{user1@primary.com user2@additional.com}, other_property: :other_value
# role :db,  %w{deploy@example.com}



# Configuration
# =============
# You can set any configuration variable like in config/deploy.rb
# These variables are then only loaded and set in this stage.
# For available Capistrano configuration variables see the documentation page.
# http://capistranorb.com/documentation/getting-started/configuration/
# Feel free to add new variables to customise your setup.



# Custom SSH Options
# ==================
# You may pass any option but keep in mind that net/ssh understands a
# limited set of options, consult the Net::SSH documentation.
# http://net-ssh.github.io/net-ssh/classes/Net/SSH.html#method-c-start
#
# Global options
# --------------
#  set :ssh_options, {
#    keys: %w(/home/user_name/.ssh/id_rsa),
#    forward_agent: false,
#    auth_methods: %w(password)
#  }
#
# The server-based syntax can be used to override options:
# ------------------------------------
# Staging server
# ------------------------------------
# server '13.158.129.88',
#   user: 'ubuntu',
#   roles: %w[web app db],
#   ssh_options: {
#     user: 'ubuntu', # overrides user setting above
#     keys: %w[~/.ssh/personal/baka-backend],
#     forward_agent: false,
#     auth_methods: %w[publickey password]
#     # password: "please use keys"
#   }

keys = ENV.fetch('KEY_PATH', nil)
production_keys = keys ? [keys] : %w[~/.ssh/aliases/thinhld-3towers]

servers = {
  'main' => {
    ip: '171.244.139.34',
    sidekiq_unit: 'sidekiq',
    puma_unit: 'puma',
    ssh_keys: production_keys
  }
}

target_server = ENV.fetch('DEPLOY_SERVER', 'all')

if target_server == 'all'
  servers.each do |name, config|
    server config[:ip],
      user: 'ubuntu',
      roles: %w[web app db],
      sidekiq_systemd_unit_name: config[:sidekiq_unit],
      puma_systemd_unit_name: config[:puma_unit],
      ssh_options: {
        user: 'ubuntu',
        keys: config[:ssh_keys],
        forward_agent: false,
        auth_methods: %w[publickey password]
      }
  end
elsif servers[target_server]
  config = servers[target_server]
  server config[:ip],
    user: 'ubuntu',
    roles: %w[web app db],
    sidekiq_systemd_unit_name: config[:sidekiq_unit],
    puma_systemd_unit_name: config[:puma_unit],
    ssh_options: {
      user: 'ubuntu',
      keys: config[:ssh_keys],
      forward_agent: false,
      auth_methods: %w[publickey password]
    }
else
  raise "Unknown server: #{target_server}. Available: #{servers.keys.join(', ')}, 'all'"
end

set :default_env, {
  'RAILS_ENV' => 'production',
  'RACK_ENV' => 'production'
}
