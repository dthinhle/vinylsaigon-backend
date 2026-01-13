# Simple DB-backed key/value store for application settings.
# Keep API minimal: lookup by name and read/write string values.
# == Schema Information
#
# Table name: system_configs
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  value      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_system_configs_on_name  (name) UNIQUE
#
class SystemConfig < ApplicationRecord
  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :value, presence: true

  # Returns the record matching the given name (or nil)
  scope :by_name, ->(name) { find_by(name: name) }
end
