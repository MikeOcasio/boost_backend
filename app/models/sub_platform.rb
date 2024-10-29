# app/models/sub_platform.rb
class SubPlatform < ApplicationRecord
  belongs_to :platform
  has_many :platform_credentials, dependent: :destroy

  validates :platform, presence: true
  validates :name, presence: true, uniqueness: { scope: :platform_id }
end
