class Api::Admin::RewardPayoutsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_role

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    payout_type = params[:payout_type] # 'referral', 'completion', or nil for all

    reward_payouts = RewardPayout.includes(user: [:user_rewards], user_reward: [])
                                 .order(created_at: :desc)

    # Filter by payout type if specified
    reward_payouts = reward_payouts.where(payout_type: payout_type) if payout_type.present?

    paginated_payouts = reward_payouts.page(page).per(per_page)

    render json: {
      success: true,
      reward_payouts: paginated_payouts.map do |payout|
        {
          id: payout.id,
          user_name: "#{payout.user.first_name} #{payout.user.last_name}",
          user_email: payout.user.email,
          recipient_email: payout.recipient_email,
          amount: payout.amount,
          payout_type: payout.payout_type,
          title: payout.title,
          status: payout.status,
          points_required: payout.user_reward.points,
          paypal_batch_id: payout.paypal_payout_batch_id,
          paypal_item_id: payout.paypal_payout_item_id,
          created_at: payout.created_at,
          processed_at: payout.processed_at,
          failure_reason: payout.failure_reason,
          paypal_response: payout.paypal_response
        }
      end,
      pagination: {
        current_page: paginated_payouts.current_page,
        total_pages: paginated_payouts.total_pages,
        total_count: paginated_payouts.total_count,
        per_page: per_page
      },
      summary: {
        total_payouts: RewardPayout.count,
        pending: RewardPayout.pending.count,
        processing: RewardPayout.processing.count,
        success: RewardPayout.successful.count,
        failed: RewardPayout.failed.count,
        total_amount: RewardPayout.sum(:amount),
        successful_amount: RewardPayout.successful.sum(:amount),
        by_type: {
          referral: {
            count: RewardPayout.referral_payouts.count,
            amount: RewardPayout.referral_payouts.sum(:amount),
            successful_amount: RewardPayout.referral_payouts.successful.sum(:amount)
          },
          completion: {
            count: RewardPayout.completion_payouts.count,
            amount: RewardPayout.completion_payouts.sum(:amount),
            successful_amount: RewardPayout.completion_payouts.successful.sum(:amount)
          }
        }
      }
    }
  end

  def show
    reward_payout = RewardPayout.find(params[:id])

    # Get detailed status from PayPal if we have the batch ID
    paypal_status = if reward_payout.paypal_payout_batch_id.present?
                      PaypalService.get_payout_status(reward_payout.paypal_payout_batch_id,
                                                      reward_payout.paypal_payout_item_id)
                    else
                      { success: false, error: 'No PayPal batch ID available' }
                    end

    render json: {
      success: true,
      reward_payout: {
        id: reward_payout.id,
        amount: reward_payout.amount,
        payout_type: reward_payout.payout_type,
        title: reward_payout.title,
        status: reward_payout.status,
        user: {
          id: reward_payout.user.id,
          name: "#{reward_payout.user.first_name} #{reward_payout.user.last_name}",
          email: reward_payout.user.email,
          total_completion_points: reward_payout.user.completion_points,
          total_referral_points: reward_payout.user.referral_points
        },
        user_reward: {
          id: reward_payout.user_reward.id,
          points: reward_payout.user_reward.points,
          reward_type: reward_payout.user_reward.reward_type,
          status: reward_payout.user_reward.status,
          claimed_at: reward_payout.user_reward.claimed_at
        },
        recipient_email: reward_payout.recipient_email,
        paypal_batch_id: reward_payout.paypal_payout_batch_id,
        paypal_item_id: reward_payout.paypal_payout_item_id,
        failure_reason: reward_payout.failure_reason,
        created_at: reward_payout.created_at,
        processed_at: reward_payout.processed_at,
        paypal_response: reward_payout.paypal_response,
        live_paypal_status: paypal_status
      }
    }
  end

  def create_payouts
    # Create payouts for all claimed rewards that haven't been paid yet
    user_rewards = UserReward.includes(:user, :reward_payouts)
                             .where(status: 'claimed')
                             .where.not(id: RewardPayout.select(:user_reward_id))

    if user_rewards.empty?
      return render json: {
        success: false,
        message: 'No rewards available for payout'
      }, status: :unprocessable_entity
    end

    created_payouts = []
    failed_payouts = []

    user_rewards.each do |reward|
      # Let the reward determine the correct PayPal email based on user role
      payout = reward.create_payout!
      created_payouts << {
        id: payout.id,
        user: "#{reward.user.first_name} #{reward.user.last_name}",
        user_role: reward.user.role,
        recipient_email: payout.recipient_email,
        amount: payout.amount,
        type: payout.payout_type
      }
    rescue StandardError => e
      failed_payouts << {
        user: "#{reward.user.first_name} #{reward.user.last_name}",
        user_role: reward.user.role,
        error: e.message
      }
    end

    render json: {
      success: true,
      message: "Created #{created_payouts.count} reward payouts",
      created_payouts: created_payouts,
      failed_payouts: failed_payouts,
      total_amount: created_payouts.sum { |p| p[:amount] }
    }
  end

  def process_payouts
    # Process all pending reward payouts
    pending_payouts = RewardPayout.pending.includes(:user, :user_reward)

    if pending_payouts.empty?
      return render json: {
        success: false,
        message: 'No pending payouts to process'
      }, status: :unprocessable_entity
    end

    processed_count = 0
    failed_count = 0

    pending_payouts.each do |payout|
      RewardPayoutJob.perform_later(payout.id)
      processed_count += 1
    rescue StandardError => e
      Rails.logger.error "Failed to queue reward payout job for payout #{payout.id}: #{e.message}"
      failed_count += 1
    end

    render json: {
      success: true,
      message: "Queued #{processed_count} reward payouts for processing",
      processed_count: processed_count,
      failed_count: failed_count,
      total_payouts: pending_payouts.count
    }
  end

  def status_check
    # Check all pending/processing reward payouts
    pending_payouts = RewardPayout.where(status: ['pending', 'processing'])

    updated_count = 0
    errors = []

    pending_payouts.each do |payout|
      next unless payout.paypal_payout_batch_id.present?

      begin
        status_result = PaypalService.get_payout_status(payout.paypal_payout_batch_id, payout.paypal_payout_item_id)

        if status_result[:success] && status_result[:status] != payout.status
          old_status = payout.status

          if status_result[:status] == 'success'
            payout.mark_as_successful!(status_result[:response])
          elsif status_result[:status] == 'failed'
            payout.mark_as_failed!(status_result[:error] || 'PayPal payout failed', status_result[:response])
          else
            payout.update!(
              status: status_result[:status],
              paypal_response: status_result[:response]
            )
          end

          updated_count += 1
          Rails.logger.info "Updated reward payout #{payout.id} from #{old_status} to #{status_result[:status]}"
        end
      rescue StandardError => e
        errors << "Reward Payout #{payout.id}: #{e.message}"
        Rails.logger.error "Failed to check reward payout #{payout.id}: #{e.message}"
      end
    end

    render json: {
      success: true,
      message: 'Reward payout status check completed',
      updated_count: updated_count,
      checked_count: pending_payouts.count,
      errors: errors
    }
  end

  private

  def ensure_admin_role
    return if current_user&.role == 'admin'

    render json: { error: 'Admin access required' }, status: :forbidden
  end
end
