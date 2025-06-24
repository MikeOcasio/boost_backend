class Api::CustomerWalletController < ApplicationController
  before_action :authenticate_user!

  def show
    # Get user rewards and payout history
    user_rewards = current_user.user_rewards.includes(:reward_payouts)
    reward_payouts = current_user.reward_payouts.order(created_at: :desc)

    # Calculate totals
    total_earned = user_rewards.sum(:amount_earned) || 0
    total_paid_out = reward_payouts.where(status: 'completed').sum(:amount) || 0
    pending_payouts = reward_payouts.where(status: ['pending', 'processing']).sum(:amount) || 0
    available_balance = total_earned - total_paid_out - pending_payouts

    # Get recent reward history
    recent_rewards = user_rewards.order(created_at: :desc).limit(10).map do |reward|
      {
        id: reward.id,
        reward_type: reward.reward_type,
        amount: reward.amount_earned,
        points_earned: reward.points_earned,
        created_at: reward.created_at,
        description: reward_description(reward)
      }
    end

    # Get payout history
    payout_history = reward_payouts.limit(10).map do |payout|
      {
        id: payout.id,
        amount: payout.amount,
        status: payout.status,
        paypal_email: payout.paypal_email,
        created_at: payout.created_at,
        processed_at: payout.processed_at,
        paypal_payout_id: payout.paypal_payout_id,
        error_message: payout.error_message
      }
    end

    render json: {
      success: true,
      wallet: {
        total_earned: total_earned,
        total_paid_out: total_paid_out,
        pending_payouts: pending_payouts,
        available_balance: available_balance,
        paypal_setup_status: current_user.customer_paypal_setup_status,
        paypal_email: current_user.cust_paypal_email,
        paypal_verified: current_user.customer_paypal_email_verified?,
        paypal_verified_at: current_user.cust_paypal_email_verified_at,
        can_receive_payouts: current_user.can_receive_paypal_payouts?
      },
      recent_rewards: recent_rewards,
      payout_history: payout_history
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def setup_paypal
    paypal_email = params[:paypal_email]
    verify_email = params[:verify_email] == 'true' || params[:verify_email] == true

    # Validate PayPal email format
    unless paypal_email.present? && valid_email?(paypal_email)
      return render json: {
        success: false,
        error: 'Valid PayPal email is required'
      }, status: :unprocessable_entity
    end

    # Update customer PayPal email
    current_user.update_customer_paypal_email(paypal_email)

    # Attempt verification if requested
    verification_result = { success: true, message: 'PayPal email updated successfully' }
    if verify_email
      begin
        # For now, we'll mark as verified immediately
        # In production, you might want to send a verification email or use PayPal API
        current_user.verify_customer_paypal_email!
        verification_result[:message] = 'PayPal email verified successfully'
      rescue StandardError => e
        verification_result = { success: false, error: "Verification failed: #{e.message}" }
      end
    end

    unless verification_result[:success]
      return render json: {
        success: false,
        error: verification_result[:error],
        verification_failed: true
      }, status: :unprocessable_entity
    end

    render json: {
      success: true,
      message: verification_result[:message],
      paypal_email: current_user.cust_paypal_email,
      verified: current_user.customer_paypal_email_verified?,
      verified_at: current_user.cust_paypal_email_verified_at,
      setup_status: current_user.customer_paypal_setup_status
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def verify_paypal
    unless current_user.cust_paypal_email.present?
      return render json: {
        success: false,
        error: 'PayPal email must be set before verification'
      }, status: :unprocessable_entity
    end

    # Verify the PayPal email
    current_user.verify_customer_paypal_email!

    render json: {
      success: true,
      message: 'PayPal email verified successfully',
      paypal_email: current_user.cust_paypal_email,
      verified: true,
      verified_at: current_user.cust_paypal_email_verified_at,
      setup_status: current_user.customer_paypal_setup_status
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def request_payout
    # Find claimed rewards that don't have payouts yet
    available_rewards = current_user.user_rewards
                                    .where(status: 'claimed')
                                    .where.not(id: RewardPayout.select(:user_reward_id))

    if available_rewards.empty?
      return render json: {
        success: false,
        error: 'No rewards available for payout. You need to have claimed rewards to request a payout.',
        setup_status: current_user.customer_paypal_setup_status
      }, status: :unprocessable_entity
    end

    # Validate user has PayPal configured
    unless current_user.can_receive_paypal_payouts?
      return render json: {
        success: false,
        error: 'PayPal account not configured or verified',
        setup_status: current_user.customer_paypal_setup_status
      }, status: :unprocessable_entity
    end

    # Calculate total available for payout
    total_available = available_rewards.sum(&:amount)
    requested_amount = params[:amount]&.to_f

    # If no amount specified, payout all available rewards
    if requested_amount.nil?
      rewards_to_payout = available_rewards
    else
      # Validate requested amount
      if requested_amount <= 0
        return render json: {
          success: false,
          error: 'Payout amount must be greater than 0'
        }, status: :unprocessable_entity
      end

      if requested_amount > total_available
        return render json: {
          success: false,
          error: 'Insufficient balance',
          available_balance: total_available,
          requested_amount: requested_amount
        }, status: :unprocessable_entity
      end

      # Select rewards up to the requested amount
      rewards_to_payout = []
      running_total = 0
      available_rewards.each do |reward|
        if running_total + reward.amount <= requested_amount
          rewards_to_payout << reward
          running_total += reward.amount
        end
        break if running_total >= requested_amount
      end
    end

    # Create payouts for selected rewards
    created_payouts = []
    failed_payouts = []

    rewards_to_payout.each do |reward|
      payout = reward.create_payout!
      created_payouts << {
        id: payout.id,
        reward_type: reward.reward_type,
        amount: payout.amount
      }
    rescue StandardError => e
      failed_payouts << {
        reward_id: reward.id,
        error: e.message
      }
    end

    if created_payouts.empty?
      return render json: {
        success: false,
        error: 'Failed to create any payouts',
        failed_payouts: failed_payouts
      }, status: :unprocessable_entity
    end

    # Queue payout jobs
    created_payouts.each do |payout_info|
      RewardPayoutJob.perform_later(payout_info[:id])
    end

    render json: {
      success: true,
      message: "#{created_payouts.count} payout(s) requested successfully",
      payouts: created_payouts,
      failed_payouts: failed_payouts,
      total_amount: created_payouts.sum { |p| p[:amount] }
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def payout_history
    payouts = current_user.reward_payouts
                          .order(created_at: :desc)
                          .limit(params[:limit]&.to_i || 20)
                          .offset(params[:offset].to_i)

    payout_data = payouts.map do |payout|
      {
        id: payout.id,
        amount: payout.amount,
        status: payout.status,
        paypal_email: payout.paypal_email,
        currency: payout.currency,
        created_at: payout.created_at,
        processed_at: payout.processed_at,
        paypal_payout_id: payout.paypal_payout_id,
        error_message: payout.error_message
      }
    end

    render json: {
      success: true,
      payouts: payout_data,
      total_count: current_user.reward_payouts.count
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def valid_email?(email)
    email.match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
  end

  def reward_description(reward)
    case reward.reward_type
    when 'completion'
      'Order completion reward'
    when 'referral'
      'Referral reward'
    else
      'Reward earned'
    end
  end
end
