class PreferredSkillMaster < ApplicationRecord
  belongs_to :user
  belongs_to :preferred_skill_master, class_name: 'User'
end
