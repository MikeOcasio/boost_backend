class Chat < ApplicationRecord
  belongs_to :customer, class_name: 'User'
  belongs_to :booster, class_name: 'User'
  has_many :messages, dependent: :destroy

  validates :customer_id, presence: true
  validates :booster_id, presence: true

  # Ensure unique chat between customer and booster
  validates :customer_id, uniqueness: { scope: :booster_id }
end
