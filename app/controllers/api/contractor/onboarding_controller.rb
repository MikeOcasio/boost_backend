# app/controllers/api/contractor/onboarding_controller.rb
module Api
  module Contractor
    class OnboardingController < ApplicationController
      before_action :authenticate_user!

      # GET /api/contractor/onboarding/account_link
      def account_link
        contractor = current_user.contractor || current_user.create_contractor!

        # Create Stripe Connect account if not exists
        unless contractor.stripe_account_id.present?
          account = Stripe::Account.create(
            type: 'express',
            country: 'US',
            email: current_user.email,
            capabilities: {
              transfers: { requested: true },
              card_payments: { requested: true }
            }
          )

          contractor.update!(stripe_account_id: account.id)
        end

        # Create onboarding link
        account_link = Stripe::AccountLink.create(
          account: contractor.stripe_account_id,
          refresh_url: onboarding_refresh_url,
          return_url: onboarding_complete_url,
          type: 'account_onboarding'
        )

        render json: { url: account_link.url }
      end

      # GET /api/contractor/onboarding/complete
      def complete
        contractor = current_user.contractor

        # Check if account is now fully onboarded
        if contractor&.stripe_account_id.present?
          account = Stripe::Account.retrieve(contractor.stripe_account_id)

          if account.charges_enabled && account.payouts_enabled
            contractor.update!(onboarding_completed_at: Time.current)

            # Initialize balance right away
            ContractorBalanceSyncWorker.perform_async(contractor.id)

            render json: { status: 'success', charges_enabled: true, payouts_enabled: true }
          else
            render json: {
              status: 'incomplete',
              charges_enabled: account.charges_enabled,
              payouts_enabled: account.payouts_enabled
            }
          end
        else
          render json: { error: 'No Stripe account found' }, status: :not_found
        end
      end

      private

      def onboarding_refresh_url
        url_for(action: :account_link)
      end

      def onboarding_complete_url
        url_for(action: :complete)
      end
    end
  end
end
