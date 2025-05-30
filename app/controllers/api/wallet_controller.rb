require 'stripe'

class Api::WalletController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_contractor_role
  before_action :ensure_contractor_account

  STRIPE_API_KEY = Rails.application.credentials.stripe[:secret_key]

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
    begin
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
  end

  def create_stripe_account
    Stripe.api_key = STRIPE_API_KEY

    begin
      # Create Stripe Connect account for the skillmaster
      account = Stripe::Account.create({
        type: 'express',
        country: 'US', # You might want to make this configurable
        email: current_user.email,
        capabilities: {
          transfers: { requested: true }
        },
        metadata: {
          user_id: current_user.id
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
        refresh_url: 'https://www.ravenboost.com/wallet/refresh',
        return_url: 'https://www.ravenboost.com/wallet/success',
        type: 'account_onboarding'
      })

      render json: {
        success: true,
        account_id: account.id,
        onboarding_url: account_link.url
      }, status: :created
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

  private

  def ensure_contractor_role
    unless current_user.skillmaster? || current_user.admin? || current_user.dev?
      render json: { success: false, error: 'Access denied' }, status: :forbidden
    end
  end

  def ensure_contractor_account
    # Skip this check for create_stripe_account action
    return if action_name == 'create_stripe_account'

    unless current_user.contractor&.stripe_account_id.present?
      render json: {
        success: false,
        error: 'No contractor account found. Please create a Stripe account first.',
        needs_stripe_account: true
      }, status: :unprocessable_entity
    end
  end
end
