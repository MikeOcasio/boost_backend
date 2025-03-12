class SkillmasterReward < ApplicationRecord
  belongs_to :user

  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reward_type, presence: true, inclusion: { in: ['referral', 'completion'] }
  validates :status, presence: true, inclusion: { in: ['pending', 'claimed', 'paid'] }

  # Define reward thresholds
  COMPLETION_THRESHOLDS = {
    100 => { reward: 10.00, title: 'Rising Booster' },
    500 => { reward: 25.00, title: 'Skilled Booster' },
    1000 => { reward: 50.00, title: 'Elite Booster' },
    2500 => { reward: 75.00, title: 'Expert Booster' },
    5000 => { reward: 100.00, title: 'Master Booster' },
    7500 => { reward: 150.00, title: 'Veteran Booster' },
    10_000 => { reward: 200.00, title: 'Legendary Booster' }
  }

  REFERRAL_THRESHOLDS = {
    5 => { reward: 15.00, title: 'Network Starter' },
    15 => { reward: 30.00, title: 'Network Builder' },
    30 => { reward: 75.00, title: 'Network Pro' },
    50 => { reward: 100.00, title: 'Network Expert' },
    75 => { reward: 150.00, title: 'Network Master' },
    100 => { reward: 200.00, title: 'Network Elite' },
    150 => { reward: 300.00, title: 'Network Legend' }
  }

  def self.calculate_next_threshold(points, type)
    thresholds = type == 'referral' ? REFERRAL_THRESHOLDS : COMPLETION_THRESHOLDS
    thresholds.find { |threshold, _| threshold > points }&.first
  end
end
