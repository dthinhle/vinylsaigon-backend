# == Schema Information
#
# Table name: addresses
#
#  id               :bigint           not null, primary key
#  address          :string           not null
#  addressable_type :string
#  city             :string           not null
#  deleted_at       :datetime
#  district         :string
#  is_head_address  :boolean          default(FALSE)
#  map_url          :string
#  phone_numbers    :string           default([]), is an Array
#  ward             :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  addressable_id   :bigint
#
# Indexes
#
#  index_addresses_on_addressable  (addressable_type,addressable_id)
#
class Address < ApplicationRecord
  belongs_to :addressable, polymorphic: true

  def full_address
    [address, ward, district].join(', ')
  end
end
