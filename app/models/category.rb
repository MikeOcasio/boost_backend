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
  has_many :users_categories
  has_many :users, through: :users_categories

  has_many :products

  validates :name, presence: true, uniqueness: true

  after_create :add_to_cat_list

  def add_to_cat_list
    return if Category.exists?(name: name)

    Category.create(name: name)
  end
end
