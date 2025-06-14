class Api::WalletController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_contractor_role
  before_action :ensure_contractor_account

  def show
    contractor = current_user.contractor

    # Get completed orders for this skillmaster
    # Exclude orders where the current user is both skillmaster AND customer
    completed_orders = Order.joins(:user)
                            .where(assigned_skill_master_id: current_user.id, state: 'complete')
                            .where.not(user_id: current_user.id)
                            .includes(:products, :user)
                            .order(updated_at: :desc)

    # Calculate earnings summary
    earnings_data = completed_orders.map do |order|
      {
        order_id: order.id,
        internal_id: order.internal_id,
        customer_name: "#{order.user.first_name} #{order.user.last_name}",
        amount_earned: order.skillmaster_earned || 0,
        completed_at: order.updated_at,
        products: order.products.map(&:name).join(', ')
      }
    end

    render json: {
      success: true,
      wallet: {
        available_balance: contractor.available_balance,
        pending_balance: contractor.pending_balance,
        total_earned: contractor.total_earned,
        can_withdraw: contractor.can_withdraw?,
        days_until_next_withdrawal: contractor.days_until_next_withdrawal,
        last_withdrawal_at: contractor.last_withdrawal_at,
        paypal_payout_email: contractor.paypal_payout_email,
        trolley_account_status: contractor.trolley_account_status,
        tax_form_status: contractor.tax_form_status,
        can_receive_payouts: contractor.can_receive_payouts?
      },
      earnings: earnings_data
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def balance
    contractor = current_user.contractor

    if contractor
      render json: {
        success: true,
        available_balance: contractor.available_balance,
        pending_balance: contractor.pending_balance,
        total_earned: contractor.total_earned,
        can_withdraw: contractor.can_withdraw?,
        days_until_next_withdrawal: contractor.days_until_next_withdrawal,
        last_withdrawal_at: contractor.last_withdrawal_at
      }, status: :ok
    else
      render json: { success: false, error: 'Contractor account not found' }, status: :not_found
    end
  end

  def withdraw
    contractor = current_user.contractor
    amount = params[:amount].to_f

    # Validate withdrawal
    unless contractor.can_withdraw?
      return render json: {
        success: false,
        error: "You must wait #{contractor.days_until_next_withdrawal} more days before withdrawing"
      }, status: :unprocessable_entity
    end

    if amount <= 0 || amount > contractor.available_balance
      return render json: {
        success: false,
        error: 'Invalid withdrawal amount'
      }, status: :unprocessable_entity
    end

    # Validate PayPal account and tax compliance
    unless contractor.can_receive_payouts?
      return render json: {
        success: false,
        error: 'PayPal account not set up or tax compliance not complete'
      }, status: :unprocessable_entity
    end

    # Queue PayPal payout job
    PaypalPayoutJob.perform_later(contractor.id, amount)

    # Update contractor balances
    render json: {
      success: true,
      message: 'Payout initiated successfully',
      amount: amount,
      remaining_balance: contractor.reload.available_balance
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def setup_paypal_account
    contractor = current_user.contractor
    paypal_email = params[:paypal_email]

    # Validate PayPal email format
    unless paypal_email.present? && valid_email?(paypal_email)
      return render json: {
        success: false,
        error: 'Valid PayPal email is required'
      }, status: :unprocessable_entity
    end

    # Update contractor with PayPal email
    contractor.update!(paypal_payout_email: paypal_email)

    render json: {
      success: true,
      message: 'PayPal account setup successfully',
      paypal_email: paypal_email
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def submit_tax_form
    contractor = current_user.contractor
    form_type = params[:form_type]
    form_data = params[:form_data] || {}

    # Validate form type
    unless %w[W-9 W-8BEN].include?(form_type)
      return render json: {
        success: false,
        error: 'Invalid tax form type. Must be W-9 or W-8BEN'
      }, status: :unprocessable_entity
    end

    # Submit tax form
    contractor.submit_tax_form!(form_type, form_data.to_h)

    render json: {
      success: true,
      message: 'Tax form submitted for verification',
      form_type: form_type,
      status: contractor.tax_form_status
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def move_pending_to_available
    contractor = current_user.contractor
    amount_moved = contractor.move_pending_to_available

    render json: {
      success: true,
      message: 'Pending balance moved to available',
      amount_moved: amount_moved,
      available_balance: contractor.available_balance,
      pending_balance: contractor.pending_balance
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  # This method is no longer needed - PayPal account setup is handled differently
  # PayPal accounts are created using email addresses rather than separate account creation
  def create_paypal_account
    render json: {
      success: false,
      error: 'PayPal account creation is no longer needed. Use setup_paypal_account instead.'
    }, status: :gone
  end

  # This method is no longer needed - PayPal doesn't have the same account status concept
  def account_status
    contractor = current_user.contractor

    render json: {
      success: true,
      account: {
        paypal_email: contractor.paypal_payout_email,
        setup_complete: contractor.paypal_payout_email.present?,
        tax_compliance_status: contractor.tax_form_status || 'not_submitted'
      }
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def supported_countries
    render json: {
      success: true,
      countries: get_supported_countries
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def transaction_history
    contractor = current_user.contractor

    # Get completed orders that generated earnings
    completed_orders = Order.joins(:user)
                            .where(assigned_skill_master_id: current_user.id, state: 'complete')
                            .where.not(user_id: current_user.id)
                            .includes(:products, :user)
                            .order(updated_at: :desc)
                            .limit(50)

    # Get PayPal payout history
    payouts = contractor.paypal_payouts
                        .order(created_at: :desc)
                        .limit(50)

    # Combine and format transactions
    transactions = []

    # Add earnings transactions
    completed_orders.each do |order|
      transactions << {
        id: "order_#{order.id}",
        type: 'earning',
        description: "Order ##{order.internal_id} - #{order.products.map(&:name).join(', ')}",
        amount: (order.skillmaster_earned || 0).to_f,
        status: 'completed',
        date: order.updated_at,
        customer: "#{order.user.first_name} #{order.user.last_name}",
        order_id: order.id,
        paypal_capture_id: order.paypal_capture_id
      }
    end

    # Add payout transactions
    payouts.each do |payout|
      transactions << {
        id: "payout_#{payout.id}",
        type: 'withdrawal',
        description: 'PayPal earnings payout',
        amount: -payout.amount, # Negative because it's money going out
        status: payout.status,
        date: payout.created_at,
        paypal_batch_id: payout.paypal_payout_batch_id,
        failure_reason: payout.failure_reason
      }
    end

    # Sort by date (most recent first)
    transactions.sort_by! { |t| t[:date] }.reverse!

    render json: {
      success: true,
      transactions: transactions,
      summary: {
        total_earnings: (completed_orders.sum(:skillmaster_earned) || 0).to_f,
        total_withdrawals: (payouts.successful.sum(:amount) || 0).to_f,
        pending_withdrawals: (payouts.where(status: ['pending', 'processing']).sum(:amount) || 0).to_f
      }
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def withdrawal_history
    contractor = current_user.contractor

    payouts = contractor.paypal_payouts
                        .order(created_at: :desc)
                        .limit(50)

    withdrawal_data = payouts.map do |payout|
      {
        id: payout.id,
        amount: payout.amount,
        status: payout.status,
        requested_at: payout.created_at,
        paypal_batch_id: payout.paypal_payout_batch_id,
        paypal_item_id: payout.paypal_payout_item_id,
        failure_reason: payout.failure_reason,
        paypal_response: payout.paypal_response
      }
    end

    render json: {
      success: true,
      withdrawals: withdrawal_data,
      summary: {
        total_successful: (payouts.successful.sum(:amount) || 0).to_f,
        total_failed: payouts.failed.count,
        total_pending: (payouts.where(status: ['pending', 'processing']).sum(:amount) || 0).to_f
      }
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  private

  def ensure_contractor_role
    return if current_user.skillmaster? || current_user.admin? || current_user.dev?

    render json: { success: false, error: 'Access denied' }, status: :forbidden
  end

  def ensure_contractor_account
    # Skip this check for setup_paypal_account, submit_tax_form, supported_countries, balance, transaction_history, and withdrawal_history actions
    return if action_name.in?(%w[setup_paypal_account submit_tax_form supported_countries balance transaction_history
                                 withdrawal_history])

    return if current_user.contractor&.paypal_payout_email.present?

    render json: {
      success: false,
      error: 'No contractor account found. Please setup your PayPal account first.',
      needs_paypal_setup: true
    }, status: :unprocessable_entity
  end

  def get_supported_countries
    # PayPal supports many more countries than Stripe
    [
      { code: 'US', name: 'United States' },
      { code: 'CA', name: 'Canada' },
      { code: 'GB', name: 'United Kingdom' },
      { code: 'AU', name: 'Australia' },
      { code: 'FR', name: 'France' },
      { code: 'DE', name: 'Germany' },
      { code: 'IT', name: 'Italy' },
      { code: 'ES', name: 'Spain' },
      { code: 'NL', name: 'Netherlands' },
      { code: 'BE', name: 'Belgium' },
      { code: 'AT', name: 'Austria' },
      { code: 'CH', name: 'Switzerland' },
      { code: 'SE', name: 'Sweden' },
      { code: 'NO', name: 'Norway' },
      { code: 'DK', name: 'Denmark' },
      { code: 'FI', name: 'Finland' },
      { code: 'IE', name: 'Ireland' },
      { code: 'PT', name: 'Portugal' },
      { code: 'LU', name: 'Luxembourg' },
      { code: 'JP', name: 'Japan' },
      { code: 'BR', name: 'Brazil' },
      { code: 'MX', name: 'Mexico' },
      { code: 'IN', name: 'India' },
      { code: 'SG', name: 'Singapore' },
      { code: 'HK', name: 'Hong Kong' },
      { code: 'NZ', name: 'New Zealand' }
    ]
  end
end
