class UserReward < ApplicationRecord
  belongs_to :user
  has_many :reward_payouts, dependent: :destroy

  validates :points, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :reward_type, presence: true, inclusion: { in: ['referral', 'completion'] }
  validates :status, presence: true, inclusion: { in: ['pending', 'claimed', 'paid'] }

  scope :claimable, -> { where(status: 'claimed') }
  scope :payable, -> { where(status: 'claimed') }

  # Calculate the reward amount based on points and type
  def amount
    threshold_data = get_threshold_data
    threshold_data ? threshold_data[:reward] : 0.0
  end

  # Get the reward title based on points and type
  def reward_title
    threshold_data = get_threshold_data
    threshold_data ? threshold_data[:title] : "#{reward_type.capitalize} Reward"
  end

  # Create a payout for this reward
  def create_payout!(recipient_email = nil)
    # Use the appropriate PayPal email based on user role, fallback to provided email
    payout_email = recipient_email || user.payout_paypal_email

    # Validate the user can receive payouts
    unless user.can_receive_paypal_payouts?
      role_specific_error = if user.role == 'skillmaster'
                              'Contractor PayPal account not configured or verified'
                            else
                              'Customer PayPal email not configured or verified'
                            end
      raise StandardError, role_specific_error
    end

    reward_payouts.create!(
      user: user,
      amount: amount,
      payout_type: reward_type,
      recipient_email: payout_email,
      status: 'pending',
      title: reward_title
    )
  end

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

  private

  def get_threshold_data
    thresholds = reward_type == 'referral' ? REFERRAL_THRESHOLDS : COMPLETION_THRESHOLDS
    # Find the highest threshold that this points value has achieved
    achieved_thresholds = thresholds.select { |threshold, _| points >= threshold }
    return nil if achieved_thresholds.empty?

    # Return the data for the highest achieved threshold
    highest_threshold = achieved_thresholds.keys.max
    thresholds[highest_threshold]
  end
end
