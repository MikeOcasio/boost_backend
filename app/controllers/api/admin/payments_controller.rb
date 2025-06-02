class Api::Admin::PaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin_access

  def index
    # Get payment overview
    orders_with_payments = Order.where.not(payment_captured_at: nil)
                                .includes(:user, :assigned_skill_master)
                                .order(payment_captured_at: :desc)
                                .limit(50)

    total_revenue = orders_with_payments.sum(:company_earned) || 0
    total_paid_to_skillmasters = orders_with_payments.sum(:skillmaster_earned) || 0

    render json: {
      success: true,
      summary: {
        total_revenue: total_revenue,
        total_paid_to_skillmasters: total_paid_to_skillmasters,
        total_orders_processed: orders_with_payments.count
      },
      recent_payments: orders_with_payments.map do |order|
        {
          order_id: order.id,
          internal_id: order.internal_id,
          customer: "#{order.user.first_name} #{order.user.last_name}",
          skillmaster: order.assigned_skill_master ? "#{order.assigned_skill_master.first_name} #{order.assigned_skill_master.last_name}" : 'N/A',
          total_amount: (order.skillmaster_earned || 0) + (order.company_earned || 0),
          skillmaster_earned: order.skillmaster_earned,
          company_earned: order.company_earned,
          captured_at: order.payment_captured_at
        }
      end
    }, status: :ok
  end

  def contractors
    # List all contractors with their balance information
    contractors = Contractor.joins(:user)
                            .includes(:user)
                            .order('users.first_name ASC')

    render json: {
      success: true,
      contractors: contractors.map do |contractor|
        {
          id: contractor.id,
          user_id: contractor.user.id,
          name: "#{contractor.user.first_name} #{contractor.user.last_name}",
          email: contractor.user.email,
          role: contractor.user.role,
          stripe_account_id: contractor.stripe_account_id,
          stripe_account_ready: contractor.stripe_account_ready?,
          available_balance: contractor.available_balance,
          pending_balance: contractor.pending_balance,
          total_earned: contractor.total_earned,
          last_withdrawal_at: contractor.last_withdrawal_at,
          can_withdraw: contractor.can_withdraw?
        }
      end
    }, status: :ok
  end

  def force_balance_move
    contractor_id = params[:contractor_id]
    contractor = Contractor.find(contractor_id)

    amount_moved = contractor.move_pending_to_available

    render json: {
      success: true,
      message: "Moved $#{amount_moved} from pending to available for #{contractor.user.first_name} #{contractor.user.last_name}",
      contractor: {
        available_balance: contractor.available_balance,
        pending_balance: contractor.pending_balance
      }
    }, status: :ok
  end

  def payment_details
    order_id = params[:order_id]
    order = Order.find(order_id)

    payment_intent = nil
    if order.stripe_payment_intent_id.present?
      Stripe.api_key = Rails.application.credentials.stripe[:secret_key]
      begin
        payment_intent = Stripe::PaymentIntent.retrieve(order.stripe_payment_intent_id)
      rescue Stripe::StripeError => e
        Rails.logger.error "Error retrieving payment intent: #{e.message}"
      end
    end

    render json: {
      success: true,
      order: {
        id: order.id,
        internal_id: order.internal_id,
        state: order.state,
        total_price: order.total_price,
        payment_status: order.payment_status,
        payment_captured_at: order.payment_captured_at,
        skillmaster_earned: order.skillmaster_earned,
        company_earned: order.company_earned,
        stripe_session_id: order.stripe_session_id,
        stripe_payment_intent_id: order.stripe_payment_intent_id
      },
      stripe_payment_intent: if payment_intent
                               {
                                 id: payment_intent.id,
                                 amount: payment_intent.amount,
                                 currency: payment_intent.currency,
                                 status: payment_intent.status,
                                 capture_method: payment_intent.capture_method,
                                 created: Time.at(payment_intent.created)
                               }
                             else
                               nil
                             end
    }, status: :ok
  end

  private

  def ensure_admin_access
    return if current_user.admin? || current_user.dev?

    render json: { success: false, error: 'Access denied' }, status: :forbidden
  end
end
