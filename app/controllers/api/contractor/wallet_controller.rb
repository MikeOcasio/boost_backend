# app/controllers/api/contractor/wallet_controller.rb
module Api
  module Contractor
    class WalletController < ApplicationController
      before_action :authenticate_user!
      before_action :ensure_contractor!

      # GET /api/contractor/wallet
      def show
        contractor.sync_balance! if stale_balance?

        render json: {
          available: contractor.available_balance,
          pending: contractor.pending_balance,
          currency: 'usd',
          last_synced_at: contractor.last_synced_at
        }
      end

      # POST /api/contractor/wallet/payouts
      def create_payout
        amount = payout_params[:amount]

        if contractor.request_payout!(amount)
          render json: {
            message: 'Payout requested successfully',
            available: contractor.available_balance
          }
        else
          render json: { error: 'Failed to request payout' }, status: :unprocessable_entity
        end
      end

      # GET /api/contractor/wallet/payouts
      def payouts
        @payouts = contractor.payouts.order(created_at: :desc).page(params[:page]).per(10)

        render json: {
          payouts: @payouts.map { |p| {
            id: p.id,
            amount: p.amount,
            status: p.status,
            created_at: p.created_at
          }},
          total_count: contractor.payouts.count,
          page: params[:page] || 1
        }
      end

      private

      def contractor
        @contractor ||= current_user.contractor
      end

      def ensure_contractor!
        unless contractor.present?
          render json: { error: 'Contractor account required' }, status: :forbidden
        end
      end

      def stale_balance?
        contractor.last_synced_at.nil? || contractor.last_synced_at < 4.hours.ago
      end

      def payout_params
        params.permit(:amount)
      end
    end
  end
end
