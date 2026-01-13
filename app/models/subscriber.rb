# == Schema Information
#
# Table name: subscribers
#
#  id         :bigint           not null, primary key
#  email      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint
#
# Indexes
#
#  index_subscribers_on_email    (email) UNIQUE
#  index_subscribers_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Subscriber < ApplicationRecord
  belongs_to :user, optional: true

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  after_create_commit :send_welcome_email

  private

  def send_welcome_email
    WelcomeSubscriberJob.perform_later(self)
  end
end
