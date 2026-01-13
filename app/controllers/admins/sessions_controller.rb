class Admins::SessionsController < Devise::SessionsController
  layout 'admin'

  # Redirect to admin login page after sign out
  # @param resource_or_scope [Symbol, Resource]
  # @return [String] path to admin login page
  def after_sign_out_path_for(resource_or_scope)
    new_admin_session_path
  end
  # Redirect to admin dashboard after sign in
  # @param resource_or_scope [Symbol, Resource]
  # @return [String] path to admin dashboard
  def after_sign_in_path_for(resource_or_scope)
    admin_dashboard_path
  end
end
