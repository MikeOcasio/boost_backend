class PlatformCredential < ApplicationRecord
  belongs_to :user
  has_many :orders
  belongs_to :platform

  encrypts :username
  encrypts :password

  validates :username, :password, presence: true
end
