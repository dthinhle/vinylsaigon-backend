class Admin::BaseController < ActionController::Base
  include Pagy::Method
  helper Admin::BaseHelper
  layout 'admin'

  before_action :authenticate_admin!
  before_action :set_active_storage_current
  before_action :set_paper_trail_whodunnit
  before_action :set_sidebar_state
  before_action :set_clarity

  rescue_from StandardError do |exception|
    Bugsnag.notify(exception) if defined?(Bugsnag)
    raise exception
  end

  private

  def user_for_paper_trail
    return 'System' unless respond_to?(:current_admin) && current_admin

    current_admin.id.to_s
  end

  def set_clarity
    if defined?(current_admin) && current_admin
      cookies[:name] = current_admin.name
      cookies[:email] = current_admin.email

      cookies[:clarity_project_id] = ENV['MS_CLARITY_PROJECT_ID']
    end
  end

  def info_for_paper_trail
    {
      transaction_id: SecureRandom.uuid
    }
  end

  def set_active_storage_current
    ActiveStorage::Current.url_options = Rails.application.config.action_mailer.default_url_options.merge(protocol: request.protocol)
  end

  def set_sidebar_state
    @sidebar_collapsed = cookies[:sidebar_collapsed] == 'true'
  end
end
