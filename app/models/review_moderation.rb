class ReviewModeration < ApplicationRecord
  belongs_to :review
  belongs_to :moderator, class_name: 'User'
  belongs_to :user

  validates :reason, presence: true, length: { minimum: 10, maximum: 1000 }

  after_create :increment_user_strikes, if: :strike_applied?

  private

  def increment_user_strikes
    user.increment!(:strikes)

    # Ban user if they reach 3 strikes
    return unless user.strikes >= 3 && user.banned_at.nil?

    user.update!(banned_at: Time.current)
  end
end
