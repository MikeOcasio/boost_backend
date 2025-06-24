class Api::Admin::PayoutsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_role

  def index
    page = params[:page] || 1
    per_page = params[:per_page] || 20

    payouts = PaypalPayout.includes(contractor: :user)
                          .order(created_at: :desc)
                          .page(page)
                          .per(per_page)

    render json: {
      success: true,
      payouts: payouts.map do |payout|
        {
          id: payout.id,
          contractor_name: "#{payout.contractor.user.first_name} #{payout.contractor.user.last_name}",
          contractor_email: payout.contractor.paypal_payout_email,
          amount: payout.amount,
          status: payout.status,
          paypal_batch_id: payout.paypal_payout_batch_id,
          paypal_item_id: payout.paypal_payout_item_id,
          created_at: payout.created_at,
          updated_at: payout.updated_at,
          failure_reason: payout.failure_reason,
          paypal_response: payout.paypal_response
        }
      end,
      pagination: {
        current_page: payouts.current_page,
        total_pages: payouts.total_pages,
        total_count: payouts.total_count,
        per_page: per_page
      },
      summary: {
        total_payouts: PaypalPayout.count,
        pending: PaypalPayout.where(status: 'pending').count,
        processing: PaypalPayout.where(status: 'processing').count,
        success: PaypalPayout.where(status: 'success').count,
        failed: PaypalPayout.where(status: 'failed').count,
        total_amount: PaypalPayout.sum(:amount),
        successful_amount: PaypalPayout.where(status: 'success').sum(:amount)
      }
    }
  end

  def show
    payout = PaypalPayout.find(params[:id])

    # Get detailed status from PayPal if we have the batch ID
    paypal_status = if payout.paypal_payout_batch_id.present?
                      PaypalService.get_payout_status(payout.paypal_payout_batch_id, payout.paypal_payout_item_id)
                    else
                      { success: false, error: 'No PayPal batch ID available' }
                    end

    render json: {
      success: true,
      payout: {
        id: payout.id,
        amount: payout.amount,
        status: payout.status,
        contractor: {
          id: payout.contractor.id,
          name: "#{payout.contractor.user.first_name} #{payout.contractor.user.last_name}",
          email: payout.contractor.paypal_payout_email,
          available_balance: payout.contractor.available_balance,
          pending_balance: payout.contractor.pending_balance,
          total_earned: payout.contractor.total_earned
        },
        paypal_batch_id: payout.paypal_payout_batch_id,
        paypal_item_id: payout.paypal_payout_item_id,
        failure_reason: payout.failure_reason,
        created_at: payout.created_at,
        updated_at: payout.updated_at,
        paypal_response: payout.paypal_response,
        live_paypal_status: paypal_status
      }
    }
  end

  def status_check
    # Check all pending/processing payouts
    pending_payouts = PaypalPayout.where(status: ['pending', 'processing'])

    updated_count = 0
    errors = []

    pending_payouts.each do |payout|
      next unless payout.paypal_payout_batch_id.present?

      begin
        status_result = PaypalService.get_payout_status(payout.paypal_payout_batch_id, payout.paypal_payout_item_id)

        if status_result[:success] && status_result[:status] != payout.status
          old_status = payout.status
          payout.update!(
            status: status_result[:status],
            paypal_response: status_result[:response]
          )
          updated_count += 1
          Rails.logger.info "Updated payout #{payout.id} from #{old_status} to #{status_result[:status]}"
        end
      rescue StandardError => e
        errors << "Payout #{payout.id}: #{e.message}"
        Rails.logger.error "Failed to check payout #{payout.id}: #{e.message}"
      end
    end

    render json: {
      success: true,
      message: 'Status check completed',
      updated_count: updated_count,
      checked_count: pending_payouts.count,
      errors: errors
    }
  end

  def sync_with_paypal
    # Force sync all payouts with PayPal
    all_payouts = PaypalPayout.where.not(paypal_payout_batch_id: nil)

    updated_count = 0
    errors = []

    all_payouts.each do |payout|
      status_result = PaypalService.get_payout_status(payout.paypal_payout_batch_id, payout.paypal_payout_item_id)

      if status_result[:success]
        old_status = payout.status
        payout.update!(
          status: status_result[:status] || payout.status,
          paypal_response: status_result[:response]
        )

        updated_count += 1 if old_status != payout.status
      end
    rescue StandardError => e
      errors << "Payout #{payout.id}: #{e.message}"
      Rails.logger.error "Failed to sync payout #{payout.id}: #{e.message}"
    end

    render json: {
      success: true,
      message: 'PayPal sync completed',
      updated_count: updated_count,
      synced_count: all_payouts.count,
      errors: errors
    }
  end

  def combined_payouts
    # Get both contractor payouts and reward payouts for a unified view
    per_page = params[:per_page] || 20

    # Contractor payouts
    contractor_payouts = PaypalPayout.includes(contractor: :user)
                                     .order(created_at: :desc)
                                     .limit(per_page / 2)

    # Reward payouts
    reward_payouts = RewardPayout.includes(:user, :user_reward)
                                 .order(created_at: :desc)
                                 .limit(per_page / 2)

    # Combine and format
    combined = []

    contractor_payouts.each do |payout|
      combined << {
        id: "contractor_#{payout.id}",
        type: 'contractor',
        recipient_name: "#{payout.contractor.user.first_name} #{payout.contractor.user.last_name}",
        recipient_email: payout.contractor.paypal_payout_email,
        amount: payout.amount,
        status: payout.status,
        description: 'Contractor Earnings',
        paypal_batch_id: payout.paypal_payout_batch_id,
        created_at: payout.created_at,
        failure_reason: payout.failure_reason
      }
    end

    reward_payouts.each do |payout|
      combined << {
        id: "reward_#{payout.id}",
        type: 'reward',
        recipient_name: "#{payout.user.first_name} #{payout.user.last_name}",
        recipient_email: payout.recipient_email,
        amount: payout.amount,
        status: payout.status,
        description: "#{payout.title} (#{payout.payout_type.capitalize})",
        paypal_batch_id: payout.paypal_payout_batch_id,
        created_at: payout.created_at,
        failure_reason: payout.failure_reason
      }
    end

    # Sort by creation date
    combined.sort_by! { |payout| payout[:created_at] }.reverse!

    render json: {
      success: true,
      combined_payouts: combined.first(per_page),
      summary: {
        contractor_payouts: {
          total: PaypalPayout.count,
          total_amount: PaypalPayout.sum(:amount),
          successful_amount: PaypalPayout.where(status: 'success').sum(:amount)
        },
        reward_payouts: {
          total: RewardPayout.count,
          total_amount: RewardPayout.sum(:amount),
          successful_amount: RewardPayout.successful.sum(:amount),
          referral_amount: RewardPayout.referral_payouts.successful.sum(:amount),
          completion_amount: RewardPayout.completion_payouts.successful.sum(:amount)
        },
        grand_total: {
          total_payouts: PaypalPayout.count + RewardPayout.count,
          total_amount: PaypalPayout.sum(:amount) + RewardPayout.sum(:amount),
          successful_amount: PaypalPayout.where(status: 'success').sum(:amount) + RewardPayout.successful.sum(:amount)
        }
      }
    }
  end

  private

  def ensure_admin_role
    return if current_user&.role == 'admin'

    render json: { error: 'Admin access required' }, status: :forbidden
  end
end
