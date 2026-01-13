# == Schema Information
#
# Table name: stores
#
#  id            :bigint           not null, primary key
#  deleted_at    :datetime
#  facebook_url  :string
#  instagram_url :string
#  name          :string
#  youtube_url   :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
class Store < ApplicationRecord
  has_many :addresses, as: :addressable, dependent: :destroy
end
