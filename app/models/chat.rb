class Chat < ApplicationRecord
  belongs_to :customer, class_name: 'User', optional: true
  belongs_to :skillmaster, class_name: 'User'
  has_many :messages, dependent: :destroy

  validates :skill_master_id, presence: true
  validates :customer_id, uniqueness: { scope: :skill_master_id }, unless: :broadcast?

  scope :broadcasts, -> { where(broadcast: true) }

  def self.create_broadcast(sender, title)
    transaction do
      chat = create!(
        customer_id: sender.id,
        skill_master_id: sender.id,
        broadcast: true,
        title: title
      )

      # Create individual chats for each skill master
      User.where(role: 'skillmaster').each do |skill_master|
        create!(
          customer_id: sender.id,
          skill_master_id: skill_master.id,
          broadcast: true,
          title: title
        )
      end

      chat
    end
  end
end
