class PlatformCredential < ApplicationRecord
  belongs_to :user

  encrypts :username, :password

  validates :username, :password, presence: true
end
