class Platform < ApplicationRecord
  # Associations
  has_many :user_platforms, dependent: :destroy
  has_many :users, through: :user_platforms

  has_many :product_platforms, dependent: :nullify

  has_many :products, through: :product_platforms

  has_many :sub_platforms, dependent: :destroy
  has_many :platform_credentials, dependent: :destroy

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :has_sub_platforms, inclusion: { in: [true, false] } # Ensures it's either true or false

  # Scopes
  scope :with_sub_platforms, -> { where(has_sub_platforms: true) }
  scope :without_sub_platforms, -> { where(has_sub_platforms: false) }
end
