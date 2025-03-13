class RewardCalculatorService
  def self.calculate_rewards(user)
    check_completion_rewards(user)
    check_referral_rewards(user)
  end

  def self.check_completion_rewards(user)
    points = user.completion_points

    UserReward::COMPLETION_THRESHOLDS.each do |threshold, data|
      next unless points >= threshold && !user.user_rewards.exists?(points: threshold, reward_type: 'completion')

      user.user_rewards.create!(
        points: threshold,
        reward_type: 'completion',
        amount: data[:reward],
        status: 'pending'
      )
    end
  end

  def self.check_referral_rewards(user)
    points = user.referral_points

    UserReward::REFERRAL_THRESHOLDS.each do |threshold, data|
      next unless points >= threshold && !user.user_rewards.exists?(points: threshold, reward_type: 'referral')

      user.user_rewards.create!(
        points: threshold,
        reward_type: 'referral',
        amount: data[:reward],
        status: 'pending'
      )
    end
  end
end
