  # == Schema Information
  #
  # Table name: notifications
  #
  #  id               :bigint           not null, primary key
  #  user_id          :bigint           not null
  #  content          :text
  #  status           :string
  #  notification_type: string
  #  created_at       :datetime         not null
  #  updated_at       :datetime         not null
  #
  # Relationships
  # - belongs_to :user

class Notification < ApplicationRecord
  belongs_to :user
end
