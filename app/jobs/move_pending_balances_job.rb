class MovePendingBalancesJob < ApplicationJob
  queue_as :default

  def perform
    # This job should run daily to move pending balances to available balances
    # for completed orders that are older than 7 days

    cutoff_date = 7.days.ago

    # Find orders that are complete and older than 7 days with pending payments
    orders_to_process = Order.joins(:assigned_skill_master)
                             .where(state: 'complete')
                             .where('payment_captured_at < ?', cutoff_date)
                             .where.not(skillmaster_earned: nil)
                             .where('skillmaster_earned > 0')

    orders_to_process.each do |order|
      skillmaster = User.find(order.assigned_skill_master_id)
      contractor = skillmaster.contractor

      next unless contractor&.pending_balance&.> 0

      # Move the specific amount from this order to available balance
      amount_to_move = order.skillmaster_earned

      contractor.transaction do
        if contractor.pending_balance >= amount_to_move
          # Use the new approval method which updates total_earned and triggers payout
          approved_amount = contractor.approve_and_move_to_available(amount_to_move)
          Rails.logger.info "Moved $#{approved_amount} from pending to available for contractor #{contractor.id} (Order: #{order.id}) after 7-day period"
        end
      end
    end
  end
end
