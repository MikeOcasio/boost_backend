class BannedEmail < ApplicationRecord
  validates :email, presence: true, uniqueness: true
end
