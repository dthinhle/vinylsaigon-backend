# == Schema Information
#
# Table name: emailed_carts
#
#  id             :uuid             not null, primary key
#  access_token   :string           not null
#  accessed_at    :datetime
#  email          :string           not null
#  expires_at     :datetime         not null
#  recipient_type :enum             default("anonymous")
#  sent_at        :datetime         not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cart_id        :uuid             not null
#
# Indexes
#
#  index_emailed_carts_on_access_token  (access_token) UNIQUE
#  index_emailed_carts_on_cart_id       (cart_id)
#  index_emailed_carts_on_email         (email)
#  index_emailed_carts_on_expires_at    (expires_at)
#
# Foreign Keys
#
#  fk_rails_...  (cart_id => carts.id)
#
class EmailedCart < ApplicationRecord
  belongs_to :cart

  enum :recipient_type, {
    authenticated: 'authenticated',
    anonymous: 'anonymous'
  }, default: 'anonymous', validate: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :access_token, presence: true, uniqueness: true
  validates :sent_at, presence: true
  validates :expires_at, presence: true

  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :active, -> { where('expires_at >= ?', Time.current) }
  scope :accessed, -> { where.not(accessed_at: nil) }
  scope :unaccessed, -> { where(accessed_at: nil) }

  before_validation :generate_access_token, on: :create
  before_validation :set_defaults, on: :create

  def expired?
    expires_at < Time.current
  end

  def accessed?
    accessed_at.present?
  end

  def mark_accessed!
    touch(:accessed_at) unless accessed?
  end

  def share_url
    [
      FRONTEND_HOST,
      '/gio-hang',
      '?access_token=',
      access_token,
    ].join
  end

  private

  def generate_access_token
    self.access_token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_defaults
    self.sent_at ||= Time.current
    self.expires_at ||= 7.days.from_now
  end
end
