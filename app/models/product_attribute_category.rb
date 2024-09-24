
#name..................:string

class ProductAttributeCategory < ApplicationRecord

  validates :name, presence: true
  validates :name, uniqueness: true
  
end
