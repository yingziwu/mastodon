# frozen_string_literal: true

lock '3.17.2'

set :repo_url, ENV.fetch('REPO', 'https://github.com/mastodon/mastodon.git')
set :branch, ENV.fetch('BRANCH', 'main')

set :application, 'mastodon'
set :rbenv_type, :user
set :rbenv_ruby, File.read('.ruby-version').strip
set :migration_role, :app

append :linked_files, '.env.production', 'public/robots.txt'
append :linked_dirs, 'vendor/bundle', 'node_modules', 'public/system'

SYSTEMD_SERVICES = %i[sidekiq streaming web].freeze
SERVICE_ACTIONS = %i[reload restart status].freeze

namespace :systemd do
  SYSTEMD_SERVICES.each do |service|
    SERVICE_ACTIONS.each do |action|
      desc "Perform a #{action} on #{service} service"
      task "#{service}:#{action}".to_sym do
        on roles(:app) do
          # runs e.g. "sudo restart mastodon-sidekiq.service"
          sudo :systemctl, action, "#{fetch(:application)}-#{service}.service"
        end
      end
    end
  end
end

after 'deploy:publishing', 'systemd:web:reload'
after 'deploy:publishing', 'systemd:sidekiq:restart'
after 'deploy:publishing', 'systemd:streaming:restart'
