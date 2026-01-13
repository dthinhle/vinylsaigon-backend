# config valid for current version and patch releases of Capistrano
lock '~> 3.19.2'

set :application, 'baka-shop'
set :repo_url, 'git@github.com-3k:dthinhle/baka-backend.git'

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, "/var/www/my_app_name"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
# append :linked_files, "config/database.yml", 'config/master.key'

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "vendor", "storage"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
# set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :rvm_ruby_version, '3.4.1'
set :rvm_custom_path, '/usr/share/rvm'
set :copy_exclude, ['.git']
set :linked_files, fetch(:linked_files, []).push(
  'config/master.key',
  'config/credentials.yml.enc'
)
set :linked_dirs, fetch(:linked_dirs, []).push(
  'log',
  'app/assets/builds',
  'public/uploads',
  'tmp',
  'storage',
)

set :sidekiq_roles, -> { :web }
set :sidekiq_systemd_unit_name, 'sidekiq'
set :puma_roles, -> { :web }
set :puma_systemd_unit_name, 'puma'

namespace :sidekiq do
  desc 'Stop sidekiq (graceful shutdown within timeout, put unfinished tasks back to Redis)'
  task :stop do
    on roles fetch(:sidekiq_roles) do
      # See: https://github.com/mperham/sidekiq/wiki/Signals#tstp
      execute :sudo, :service, fetch(:sidekiq_systemd_unit_name), 'stop'
    end
  end

  desc 'Start sidekiq'
  task :start do
    on roles fetch(:sidekiq_roles) do
      execute :sudo, :service, fetch(:sidekiq_systemd_unit_name), 'start'
    end
  end

  desc 'Restart sidekiq'
  task :restart do
    on roles fetch(:sidekiq_roles) do
      execute :sudo, :service, fetch(:sidekiq_systemd_unit_name), 'restart'
    end
  end
end

namespace :puma do
  desc 'Start puma'
  task :start do
    on roles fetch(:puma_roles) do
      execute :sudo, :service, fetch(:puma_systemd_unit_name), 'start'
    end
  end

  desc 'Stop puma'
  task :stop do
    on roles fetch(:puma_roles) do
      execute :sudo, :service, fetch(:puma_systemd_unit_name), 'stop'
    end
  end

  desc 'Phased restart puma'
  task :phased_restart do
    on roles fetch(:puma_roles) do
      within release_path do
        execute :kill, '-10', '$(cat tmp/pids/puma.pid)'
      end
    end
  end

  desc 'Restart puma'
  task :restart do
    on roles fetch(:puma_roles) do
      execute :sudo, :service, fetch(:puma_systemd_unit_name), 'restart'
    end
  end
end

namespace :yarn do
  desc 'Install node modules with yarn'
  task :install do
    on roles(:web) do
      within release_path do
        execute :yarn, 'install'
      end
    end
  end
end

namespace :assets do
  desc 'Clean up old assets'
  task :clean do
    on roles(:web) do
      within release_path do
        execute :rake, 'assets:clean'
      end
    end
  end
end

before 'deploy:assets:precompile', 'yarn:install'
after 'deploy:assets:precompile', 'assets:clean'

after 'deploy:updated', 'sidekiq:stop'
after 'deploy:published', 'sidekiq:start'
after 'deploy:failed', 'sidekiq:restart'

after 'deploy:publishing', 'puma:phased_restart'
