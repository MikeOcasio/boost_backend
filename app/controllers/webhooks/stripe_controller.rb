# app/controllers/webhooks/stripe_controller.rb
module Webhooks
  class StripeController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      payload = request.body.read
      sig_header = request.env['HTTP_STRIPE_SIGNATURE']
      endpoint_secret = ENV['STRIPE_WEBHOOK_SECRET']

      begin
        event = Stripe::Webhook.construct_event(
          payload, sig_header, endpoint_secret
        )
      rescue JSON::ParserError => e
        return head :bad_request
      rescue Stripe::SignatureVerificationError => e
        return head :bad_request
      end

      case event.type
      when 'account.updated'
        handle_account_updated(event.data.object)
      when 'payout.created', 'payout.updated', 'payout.paid', 'payout.failed'
        handle_payout_event(event)
      when 'payment_intent.succeeded'
        handle_payment_succeeded(event.data.object)
      end

      head :ok
    end

    private

    def handle_account_updated(account)
      contractor = Contractor.find_by(stripe_account_id: account.id)
      return unless contractor

      if account.charges_enabled && account.payouts_enabled
        contractor.update!(onboarding_completed_at: Time.current) unless contractor.onboarding_completed_at
      end
    end

    def handle_payout_event(event)
      payout_data = event.data.object
      account_id = event.account

      contractor = Contractor.find_by(stripe_account_id: account_id)
      return unless contractor

      payout = contractor.payouts.find_by(stripe_payout_id: payout_data.id)

      if payout
        payout.update!(
          status: payout_data.status,
          metadata: payout_data.to_h
        )
      elsif event.type == 'payout.created'
        # Create record for payouts initiated from Stripe dashboard
        contractor.payouts.create!(
          stripe_payout_id: payout_data.id,
          amount: payout_data.amount,
          status: payout_data.status,
          metadata: payout_data.to_h
        )
      end

      # Sync balance after payout status changes
      ContractorBalanceSyncWorker.perform_async(contractor.id)
    end

    def handle_payment_succeeded(payment_intent)
      return unless payment_intent.transfer_data&.destination

      # Force a balance sync for the contractor
      contractor = Contractor.find_by(stripe_account_id: payment_intent.transfer_data.destination)
      ContractorBalanceSyncWorker.perform_async(contractor.id) if contractor
    end
  end
end
