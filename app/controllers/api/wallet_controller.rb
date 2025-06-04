require 'stripe'
require 'yaml'

class Api::WalletController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_contractor_role
  before_action :ensure_contractor_account

  STRIPE_API_KEY = Rails.application.credentials.stripe[:test_secret]

  def show
    Stripe.api_key = STRIPE_API_KEY

    begin
      contractor = current_user.contractor

      # Get completed orders for this skillmaster
      completed_orders = Order.joins(:user)
                              .where(assigned_skill_master_id: current_user.id, state: 'complete')
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
          stripe_account_id: contractor.stripe_account_id
        },
        earnings: earnings_data
      }, status: :ok
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
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
    Stripe.api_key = STRIPE_API_KEY

    begin
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

      # Create Stripe transfer to skillmaster's account
      transfer = Stripe::Transfer.create({
                                           amount: (amount * 100).to_i, # Convert to cents
                                           currency: 'usd',
                                           destination: contractor.stripe_account_id,
                                           metadata: {
                                             user_id: current_user.id,
                                             contractor_id: contractor.id,
                                             withdrawal_date: Time.current.to_s
                                           }
                                         })

      # Update contractor balances
      contractor.transaction do
        contractor.update!(
          available_balance: contractor.available_balance - amount,
          last_withdrawal_at: Time.current
        )
      end

      render json: {
        success: true,
        message: 'Withdrawal successful',
        transfer_id: transfer.id,
        amount: amount,
        remaining_balance: contractor.available_balance
      }, status: :ok
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
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

  def create_stripe_account
    Stripe.api_key = STRIPE_API_KEY

    begin
      # Get country from params, default to US
      country = params[:country]&.upcase || 'US'

      # Validate country code (basic validation)
      unless valid_stripe_country?(country)
        return render json: {
          success: false,
          error: "Unsupported country code: #{country}",
          supported_countries: get_supported_countries
        }, status: :unprocessable_entity
      end

      # Create Stripe Connect account for the skillmaster
      account = Stripe::Account.create({
                                         type: 'express',
                                         country: country,
                                         email: current_user.email,
                                         capabilities: get_capabilities_for_country(country),
                                         metadata: {
                                           user_id: current_user.id,
                                           country: country
                                         }
                                       })

      # Update or create contractor record
      if current_user.contractor
        current_user.contractor.update!(stripe_account_id: account.id)
      else
        current_user.create_contractor!(stripe_account_id: account.id)
      end

      # Create account link for onboarding
      account_link = Stripe::AccountLink.create({
                                                  account: account.id,
                                                  refresh_url: get_refresh_url,
                                                  return_url: get_return_url,
                                                  type: 'account_onboarding'
                                                })

      render json: {
        success: true,
        account_id: account.id,
        country: country,
        onboarding_url: account_link.url
      }, status: :created
    rescue Stripe::InvalidRequestError => e
      if e.message.include?('capability')
        render json: {
          success: false,
          error: 'Account setup error due to capability requirements.',
          details: e.message,
          country: country
        }, status: :unprocessable_entity
      else
        render json: { success: false, error: e.message }, status: :unprocessable_entity
      end
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  def account_status
    Stripe.api_key = STRIPE_API_KEY

    begin
      contractor = current_user.contractor

      # Get account details from Stripe
      account = Stripe::Account.retrieve(contractor.stripe_account_id)

      render json: {
        success: true,
        account: {
          id: account.id,
          charges_enabled: account.charges_enabled,
          payouts_enabled: account.payouts_enabled,
          details_submitted: account.details_submitted,
          requirements: account.requirements
        }
      }, status: :ok
    rescue Stripe::StripeError => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    rescue StandardError => e
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
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
    Stripe.api_key = STRIPE_API_KEY

    begin
      # Get all completed orders for this skillmaster with payment information
      completed_orders = Order.joins(:user)
                              .where(assigned_skill_master_id: current_user.id, state: 'complete')
                              .where.not(payment_captured_at: nil)
                              .includes(:products, :user)
                              .order(payment_captured_at: :desc)
                              .limit(50) # Limit to recent 50 transactions

      if completed_orders.empty?
        return render json: {
          success: true,
          message: 'No transaction history found',
          transactions: []
        }, status: :ok
      end

      # Build transaction history with detailed information
      transactions = completed_orders.map do |order|
        {
          transaction_id: order.id,
          order_id: order.internal_id,
          type: 'payment_received',
          customer_name: "#{order.user.first_name} #{order.user.last_name}",
          customer_email: order.user.email,
          amount_earned: order.skillmaster_earned || 0,
          total_order_amount: order.total_price || 0,
          products: order.products.map { |p| { name: p.name, price: p.price } },
          order_status: order.state,
          payment_captured_at: order.payment_captured_at,
          created_at: order.created_at,
          stripe_payment_intent_id: order.stripe_payment_intent_id
        }
      end

      render json: {
        success: true,
        message: "Found #{transactions.count} transactions",
        transactions: transactions,
        summary: {
          total_transactions: transactions.count,
          total_earned: transactions.sum { |t| t[:amount_earned] },
          period: {
            from: transactions.last&.dig(:payment_captured_at),
            to: transactions.first&.dig(:payment_captured_at)
          }
        }
      }, status: :ok
    rescue StandardError => e
      render json: {
        success: false,
        error: 'Failed to retrieve transaction history',
        details: e.message
      }, status: :internal_server_error
    end
  end

  def withdrawal_history
    Stripe.api_key = STRIPE_API_KEY

    begin
      contractor = current_user.contractor

      # Get transfer history from Stripe for this contractor's account
      transfers = Stripe::Transfer.list({
                                          destination: contractor.stripe_account_id,
                                          limit: 50 # Limit to recent 50 withdrawals
                                        })

      if transfers.data.empty?
        return render json: {
          success: true,
          message: 'No withdrawal history found',
          withdrawals: []
        }, status: :ok
      end

      # Build withdrawal history with detailed information
      withdrawals = transfers.data.map do |transfer|
        {
          withdrawal_id: transfer.id,
          amount: transfer.amount / 100.0, # Convert from cents to dollars
          currency: transfer.currency.upcase,
          status: transfer.status || 'completed',
          created_at: Time.at(transfer.created),
          description: transfer.description,
          metadata: transfer.metadata&.to_hash || {},
          destination_account: transfer.destination,
          # Additional Stripe transfer details
          transfer_group: transfer.transfer_group,
          source_transaction: transfer.source_transaction
        }
      end

      # Calculate summary statistics
      total_withdrawn = withdrawals.sum { |w| w[:amount] }
      successful_withdrawals = withdrawals.select { |w| w[:status] == 'completed' || w[:status] == 'paid' }

      render json: {
        success: true,
        message: "Found #{withdrawals.count} withdrawals",
        withdrawals: withdrawals,
        summary: {
          total_withdrawals: withdrawals.count,
          successful_withdrawals: successful_withdrawals.count,
          total_amount_withdrawn: total_withdrawn,
          last_withdrawal: withdrawals.first&.dig(:created_at),
          first_withdrawal: withdrawals.last&.dig(:created_at)
        }
      }, status: :ok
    rescue Stripe::StripeError => e
      render json: {
        success: false,
        error: 'Failed to retrieve withdrawal history from Stripe',
        details: e.message
      }, status: :unprocessable_entity
    rescue StandardError => e
      render json: {
        success: false,
        error: 'Failed to retrieve withdrawal history',
        details: e.message
      }, status: :internal_server_error
    end
  end

  private

  def ensure_contractor_role
    return if current_user.skillmaster? || current_user.admin? || current_user.dev?

    render json: { success: false, error: 'Access denied' }, status: :forbidden
  end

  def ensure_contractor_account
    # Skip this check for create_stripe_account, supported_countries, balance, transaction_history, and withdrawal_history actions
    return if action_name.in?(%w[create_stripe_account supported_countries balance transaction_history
                                 withdrawal_history])

    return if current_user.contractor&.stripe_account_id.present?

    render json: {
      success: false,
      error: 'No contractor account found. Please create a Stripe account first.',
      needs_stripe_account: true
    }, status: :unprocessable_entity
  end

  def get_supported_countries
    config_path = Rails.root.join('config/stripe_config.yml')
    stripe_config = YAML.load_file(config_path)
    countries = stripe_config['countries'] || {}
    countries.map { |code, info| { code: code, name: info['name'] } }
  rescue StandardError => e
    Rails.logger.error "Error loading supported countries config: #{e.message}"
    # Fallback list
    [
      { code: 'US', name: 'United States' },
      { code: 'CA', name: 'Canada' },
      { code: 'GB', name: 'United Kingdom' },
      { code: 'AU', name: 'Australia' },
      { code: 'FR', name: 'France' },
      { code: 'DE', name: 'Germany' }
    ]
  end

  def valid_stripe_country?(country_code)
    # Load countries from configuration file
    config_path = Rails.root.join('config/stripe_config.yml')
    stripe_config = YAML.load_file(config_path)
    stripe_config['countries']&.key?(country_code)
  rescue StandardError => e
    Rails.logger.error "Error loading stripe config: #{e.message}"
    # Fallback to hardcoded list if config fails
    supported_countries = %w[
      US CA GB AU AT BE DK FI FR DE HK IE IT LU NL NZ NO PT ES SE CH
      BR MX SG MY TH PH IN JP
    ]
    supported_countries.include?(country_code)
  end

  def get_capabilities_for_country(country)
    begin
      # Load capabilities from configuration file
      config_path = Rails.root.join('config/stripe_config.yml')
      stripe_config = YAML.load_file(config_path)
      country_config = stripe_config['countries']&.[](country)

      if country_config&.[]('capabilities')
        capabilities = {}
        country_config['capabilities'].each do |capability|
          capabilities[capability.to_sym] = { requested: true }
        end
        return capabilities
      end
    rescue StandardError => e
      Rails.logger.error "Error loading stripe capabilities config: #{e.message}"
    end

    # Fallback to default capabilities if config fails or country not found
    {
      card_payments: { requested: true },
      transfers: { requested: true }
    }
  end

  def get_refresh_url
    config_path = Rails.root.join('config/stripe_config.yml')
    stripe_config = YAML.load_file(config_path)
    stripe_config[Rails.env]&.[]('refresh_url')
  rescue StandardError => e
    Rails.logger.error "Error loading stripe refresh URL config: #{e.message}"
    # Fallback URLs
    case Rails.env
    when 'production'
      'https://www.ravenboost.com/wallet/refresh'
    when 'staging'
      'https://staging.ravenboost.com/wallet/refresh'
    else
      'http://localhost:3000/wallet/refresh'
    end
  end

  def get_return_url
    config_path = Rails.root.join('config/stripe_config.yml')
    stripe_config = YAML.load_file(config_path)
    stripe_config[Rails.env]&.[]('return_url')
  rescue StandardError => e
    Rails.logger.error "Error loading stripe return URL config: #{e.message}"
    # Fallback URLs
    case Rails.env
    when 'production'
      'https://www.ravenboost.com/wallet/success'
    when 'staging'
      'https://staging.ravenboost.com/wallet/success'
    else
      'http://localhost:3000/wallet/success'
    end
  end
end
