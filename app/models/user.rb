# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  deleted_at             :datetime
#  disabled               :boolean          default(FALSE)
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  jti                    :string
#  name                   :string           default(""), not null
#  phone_number           :string
#  refresh_token          :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_deleted_at            (deleted_at)
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  include JwtAuthable
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  after_create :link_to_subscriber
  before_validation :set_name

  validates :name, presence: true, length: { maximum: 255 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  has_one :subscriber
  has_many :orders, dependent: :nullify
  has_many :refresh_tokens, dependent: :destroy

  private

  def set_name
    return unless new_record? || name.blank?
    return unless email.present? && email.include?('@')

    self.name = email.split('@').first
  end

  def link_to_subscriber
    subscriber = Subscriber.find_by(email: email)
    subscriber&.update(user: self)
  end
end
