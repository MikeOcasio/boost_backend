  # == Schema Information
  #
  # Table name: categories
  #
  #  id          :bigint           not null, primary key
  #  name        :string
  #  description :text
  #  created_at  :datetime         not null
  #  updated_at  :datetime         not null
  #
  # Relationships
  # - has_many :products


class Category < ApplicationRecord

  has_many :products

  validates :name, presence: true, uniqueness: true

  after_create :add_to_cat_list

  def add_to_cat_list
    unless Category.exists?(name: self.name)
      Category.create(name: self.name)
    end
  end

end
