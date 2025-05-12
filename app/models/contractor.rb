class Contractor < ApplicationRecord
  belongs_to :user

  validates :stripe_account_id, presence: true, uniqueness: true
end
