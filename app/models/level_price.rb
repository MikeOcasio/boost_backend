class LevelPrice < ApplicationRecord
  belongs_to :category

  validates :min_level, :max_level, :price_per_level, presence: true
end
