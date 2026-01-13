# frozen_string_literal: true

# AdminCreatorService creates a new admin account with a randomly generated password
# and sends a welcome email with login credentials.
#
# Usage:
#   AdminCreatorService.call(admin_params: { name: 'John Doe', email: 'john@example.com' })
#
class AdminCreatorService
  class InvalidAdminDataError < StandardError; end

  def self.call(admin_params:)
    new(admin_params: admin_params).call
  end

  def initialize(admin_params:)
    @admin_params = admin_params
  end

  def call
    Admin.transaction do
      admin = Admin.new(@admin_params)

      if admin.save(validate: false)
        raw_token, encrypted_token = Devise.token_generator.generate(Admin, :reset_password_token)
        admin.reset_password_token = encrypted_token
        admin.reset_password_sent_at = Time.current
        admin.save(validate: false)

        Rails.logger.info("AdminCreatorService: Created admin #{admin.email} (ID: #{admin.id})")
        AdminMailer.welcome_email(admin, raw_token).deliver_later
        admin
      else
        Rails.logger.error("AdminCreatorService: Failed to create admin - #{admin.errors.full_messages.join(', ')}")
        raise InvalidAdminDataError, admin.errors.full_messages.to_sentence
      end
    end
  end
end
