class UserReward < ApplicationRecord
  belongs_to :user

  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reward_type, presence: true, inclusion: { in: ['referral', 'completion'] }
  validates :status, presence: true, inclusion: { in: ['pending', 'claimed', 'paid'] }

  # Define reward thresholds
  COMPLETION_THRESHOLDS = {
    100 => { reward: 10.00, title: 'Rising Star' },
    500 => { reward: 25.00, title: 'Skilled Member' },
    1000 => { reward: 50.00, title: 'Elite Member' },
    2500 => { reward: 75.00, title: 'Expert Member' },
    5000 => { reward: 100.00, title: 'Master Member' },
    7500 => { reward: 150.00, title: 'Veteran Member' },
    10_000 => { reward: 200.00, title: 'Legendary Member' }
  }

  REFERRAL_THRESHOLDS = {
    5 => { reward: 15.00, title: 'Referral Starter' },
    15 => { reward: 30.00, title: 'Referral Builder' },
    30 => { reward: 75.00, title: 'Referral Pro' },
    50 => { reward: 100.00, title: 'Referral Expert' },
    75 => { reward: 150.00, title: 'Referral Master' },
    100 => { reward: 200.00, title: 'Referral Elite' },
    150 => { reward: 300.00, title: 'Referral Legend' }
  }

  def self.calculate_next_threshold(points, type)
    thresholds = type == 'referral' ? REFERRAL_THRESHOLDS : COMPLETION_THRESHOLDS
    thresholds.find { |threshold, _| threshold > points }&.first
  end
end
