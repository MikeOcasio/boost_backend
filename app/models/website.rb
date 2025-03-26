class Website < ApplicationRecord
  has_many :reviews, as: :reviewable

  # This can be a singleton model or just have a single record
  def self.instance
    first_or_create(name: 'Ravenboost Website')
  end
end
