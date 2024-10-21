class CategorySkillmasterApp < ApplicationRecord
  # Define the associations
  belongs_to :category
  belongs_to :skillmaster_application

  # You can add validations, callbacks, or any additional logic here
end
