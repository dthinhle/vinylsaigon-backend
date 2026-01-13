class Admins::PasswordsController < Devise::PasswordsController
  layout 'admin'

  # Redirect to admin dashboard after password reset
  # @param resource [Resource]
  # @return [String] path to admin dashboard
  def after_resetting_password_path_for(resource)
    admin_dashboard_path
  end
end
