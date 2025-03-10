class RewardCalculatorService
  def self.calculate_rewards(user)
    check_completion_rewards(user)
    check_referral_rewards(user)
  end

  def self.check_completion_rewards(user)
    points = user.completion_points

    SkillmasterReward::COMPLETION_THRESHOLDS.each do |threshold, data|
      next unless points >= threshold && !user.skillmaster_rewards.exists?(points: threshold, reward_type: 'completion')

      user.skillmaster_rewards.create!(
        points: threshold,
        reward_type: 'completion',
        amount: data[:reward],
        status: 'pending'
      )
    end
  end

  def self.check_referral_rewards(user)
    points = user.referral_points

    SkillmasterReward::REFERRAL_THRESHOLDS.each do |threshold, data|
      next unless points >= threshold && !user.skillmaster_rewards.exists?(points: threshold, reward_type: 'referral')

      user.skillmaster_rewards.create!(
        points: threshold,
        reward_type: 'referral',
        amount: data[:reward],
        status: 'pending'
      )
    end
  end
end
