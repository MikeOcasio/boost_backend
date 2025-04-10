class SkillmasterApplication < ApplicationRecord
  include AASM

  belongs_to :user

  validates :gamer_tag, presence: true
  validates :reasons, presence: true

  validate :channels_must_be_valid_urls

  # images can be stored as an array of strings (URLs or paths)

  aasm column: 'status' do
    state :submitted, initial: true
    state :approved
    state :denied

    event :approve do
      transitions from: :submitted, to: :approved
    end

    event :deny do
      transitions from: :submitted, to: :denied
    end

    event :reopen do
      transitions from: %i[denied approved], to: :submitted, guard: :reapply_allowed?
    end
  end

  private

  def channels_must_be_valid_urls
    return if channels.blank?

    channels.each do |url|
      unless url =~ /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/
        errors.add(:channels, "#{url} is not a valid URL")
      end
    end
  end

  def reapply_allowed?
    # Logic to ensure reapplication is only allowed after a specific period (e.g., 30 days)
    return false if status == 'approved'

    denied_at = self.reviewed_at
    denied_at && denied_at <= 30.days.ago
  end
end
