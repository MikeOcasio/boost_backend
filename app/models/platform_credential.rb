class PlatformCredential < ApplicationRecord
  belongs_to :user
  has_many :orders
  belongs_to :platform
  belongs_to :sub_platform, optional: true

  encrypts :username
  encrypts :password

  validates :username, :password, presence: true
end
