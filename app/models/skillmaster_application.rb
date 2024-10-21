class SkillmasterApplication < ApplicationRecord
  belongs_to :user
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :platforms

  validates :gamer_tag, presence: true
  validates :reasons, presence: true

  # images can be stored as an array of strings (URLs or paths)
end
