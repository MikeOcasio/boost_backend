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
    verify_email = params[:verify_email] == 'true' || params[:verify_email] == true

    # Validate PayPal email format
    unless paypal_email.present? && valid_email?(paypal_email)
      return render json: {
        success: false,
        error: 'Valid PayPal email is required'
      }, status: :unprocessable_entity
    end

    # Check if email changed - reset verification if it did
    if contractor.paypal_payout_email != paypal_email && contractor.paypal_email_verified?
      contractor.reset_paypal_verification!
    end

    # Update contractor with PayPal email
    contractor.update!(paypal_payout_email: paypal_email)

    # Attempt verification if requested
    verification_result = nil
    if verify_email
      verification_result = contractor.verify_paypal_email!

      unless verification_result[:success]
        return render json: {
          success: false,
          error: verification_result[:error],
          verification_failed: true,
          can_retry: contractor.can_attempt_verification?
        }, status: :unprocessable_entity
      end
    end

    render json: {
      success: true,
      message: 'PayPal account setup successfully',
      paypal_email: paypal_email,
      verified: contractor.paypal_email_verified?,
      verified_at: contractor.paypal_email_verified_at,
      verification_message: verification_result&.[](:message)
    }, status: :ok
  rescue StandardError => e
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def submit_tax_form
    contractor = current_user.contractor
    country_code = params[:country_code]
    form_data = params[:form_data] || {}

    # Set country if provided
    if country_code.present?
      country_info = Contractor.country_info(country_code)
      contractor.update!(
        country_code: country_code.upcase,
        country_name: country_info[:name],
        tax_id_type: country_info[:tax_id_label],
        withholding_rate: country_info[:withholding_rate]
      )
    end

    # Auto-detect required form based on country
    form_type = contractor.required_tax_form_type

    # Validate based on form type and country
    validate_international_tax_form!(contractor, form_data)

    contractor.submit_tax_form!(form_type, form_data.to_h)

    render json: {
      success: true,
      message: "#{form_type} submitted for verification",
      form_type: form_type,
      status: contractor.tax_form_status,
      country: contractor.country_name,
      withholding_info: contractor.calculate_net_payout(100), # Show example with $100
      tax_id_label: contractor.tax_id_label
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
        amount: order.skillmaster_earned || 0,
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
        total_earnings: completed_orders.sum(:skillmaster_earned) || 0,
        total_withdrawals: payouts.successful.sum(:amount) || 0,
        pending_withdrawals: payouts.where(status: ['pending', 'processing']).sum(:amount) || 0
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
        total_successful: payouts.successful.sum(:amount) || 0,
        total_failed: payouts.failed.count,
        total_pending: payouts.where(status: ['pending', 'processing']).sum(:amount) || 0
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
    # Return countries with their tax requirements
    Contractor::COUNTRY_TAX_INFO.map do |country|
      {
        code: country[:code],
        name: country[:name],
        tax_form: country[:tax_form],
        tax_id_label: country[:tax_id_label],
        withholding_rate: country[:withholding_rate],
        requires_date_of_birth: country[:requires_date_of_birth]
      }
    end
  end

  def validate_international_tax_form!(contractor, form_data)
    country_info = contractor.country_info

    # Map form field names to encrypted model attributes
    field_mapping = {
      'full_name' => 'full_legal_name',
      'tax_id_number' => 'tax_id',
      'address_line1' => 'address_line_1',
      'address_line2' => 'address_line_2',
      'city' => 'city',
      'state_province' => 'state_province',
      'postal_code' => 'postal_code',
      'date_of_birth' => 'date_of_birth'
    }

    # Common required fields for all contractors
    required_fields = %w[full_name tax_id_number address_line1 city postal_code]

    # Add date of birth for non-US contractors
    required_fields << 'date_of_birth' if contractor.requires_date_of_birth?

    required_fields.each do |field|
      next if form_data[field].present?

      human_field = field.humanize
      human_field = contractor.tax_id_label if field == 'tax_id_number'
      raise "#{human_field} is required for #{country_info[:name]} contractors"
    end

    # Validate tax ID format if we have a pattern for this country
    tax_id = form_data['tax_id_number']
    unless contractor.validate_tax_id_format(tax_id)
      raise "Please enter a valid #{contractor.tax_id_label} for #{contractor.country_name}"
    end

    # Store encrypted contractor information using the encrypted setters
    update_attrs = {}
    field_mapping.each do |form_field, model_attr|
      update_attrs[model_attr] = form_data[form_field] if form_data[form_field].present?
    end

    contractor.update!(update_attrs)
  end
  end

  def valid_email?(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end
end
