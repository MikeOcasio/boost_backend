class SkillmasterApplication < ApplicationRecord
  include AASM

  belongs_to :user
  has_and_belongs_to_many :categories
  has_and_belongs_to_many :platforms

  validates :gamer_tag, presence: true
  validates :reasons, presence: true

  # images can be stored as an array of strings (URLs or paths)

  aasm column: 'status' do
    state :submitted, initial: true
    state :under_review
    state :appro
ved
    state :denied
    event :submit do
      transitions from: :submitted, to: :under_review
    end

    event :review do
      transitions from: :under_review, to: :approved
      transitions from: :under_review, to: :denied

    event :reopen do
      transitions from: [:denied, :approved], to: :submitted, guard: :reapply_allowed?
    end
  end

  private

  def reapply_allowed?
    # Logic to ensure reapplication is only allowed after a specific period (e.g., 30 days)
    return false if status == 'approved'

    denied_at = self.reviewed_at
    denied_at && denied_at <= 30.days.ago
  end
end
