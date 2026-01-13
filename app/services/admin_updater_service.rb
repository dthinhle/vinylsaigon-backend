# frozen_string_literal: true

class AdminUpdaterService
  class EmailConfirmationMismatchError < StandardError; end
  class InvalidAdminDataError < StandardError; end

  def self.call(admin:, admin_params:, current_admin:)
    new(admin, admin_params, current_admin).call
  end

  def initialize(admin, admin_params, current_admin)
    @admin = admin
    @admin_params = admin_params.dup
    @current_admin = current_admin
  end

  def call
    sanitize_params
    validate_email_confirmation if updating_own_email?

    if @admin.update(@admin_params)
      @admin
    else
      raise InvalidAdminDataError, @admin.errors.full_messages.to_sentence
    end
  end

  private

  def sanitize_params
    @admin_params.delete(:password) if @admin_params[:password].blank?
    @admin_params.delete(:email_confirmation)
  end

  def updating_own_email?
    @admin.id == @current_admin.id &&
      @admin_params[:email].present? &&
      @admin_params[:email] != @admin.email
  end

  def validate_email_confirmation
    unless @admin_params[:email] == @admin_params[:email_confirmation]
      raise EmailConfirmationMismatchError, 'Email confirmation does not match. Please verify the new email address.'
    end
  end
end
