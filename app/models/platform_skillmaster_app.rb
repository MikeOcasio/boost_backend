class PlatformSkillmasterApp < ApplicationRecord
  # Define the associations
  belongs_to :platform
  belongs_to :skillmaster_application

  # Additional validations, methods, or logic can go here
end
