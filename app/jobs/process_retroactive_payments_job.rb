class ProcessRetroactivePaymentsJob < ApplicationJob
  queue_as :default

  def perform(contractor_id)
    contractor = Contractor.find(contractor_id)
    skillmaster = contractor.user

    Rails.logger.info "Processing retroactive payments for contractor #{contractor_id} (skillmaster: #{skillmaster.id})"

    # Find all completed orders for this skillmaster that:
    # 1. Have captured payments (payment_captured_at is not nil)
    # 2. Have skillmaster_earned amount but payment wasn't added to contractor balance
    # 3. Order was completed before contractor account was created
    orders_to_process = Order.where(
      assigned_skill_master_id: skillmaster.id,
      state: 'complete'
    ).where(
      'payment_captured_at IS NOT NULL AND skillmaster_earned IS NOT NULL AND skillmaster_earned > 0'
    )

    total_retroactive_amount = 0
    processed_orders = []

    orders_to_process.each do |order|
      # Check if this payment was already processed (order was completed after contractor account creation)
      # If contractor was created before order completion, payment should have been processed normally
      if contractor.created_at <= order.payment_captured_at
        Rails.logger.debug { "Skipping order #{order.id} - contractor account existed when payment was captured" }
        next
      end

      # This is a retroactive payment - order was completed before contractor account existed
      amount = order.skillmaster_earned

      Rails.logger.info "Processing retroactive payment for order #{order.id}: $#{amount}"

      # Add to contractor's pending balance (following the same 7-day pending rule)
      contractor.add_to_pending_balance(amount)
      total_retroactive_amount += amount
      processed_orders << order.id

      # Log retroactive payment in order (could add a field later to track this)
      Rails.logger.info "Added $#{amount} to pending balance for contractor #{contractor_id} from order #{order.id}"
    end

    if total_retroactive_amount > 0
      Rails.logger.info "Retroactive payment processing complete for contractor #{contractor_id}: $#{total_retroactive_amount} from #{processed_orders.count} orders (Orders: #{processed_orders.join(', ')})"

      # Optionally, you could send a notification to the skillmaster about retroactive payments
      # NotificationService.send_retroactive_payment_notification(skillmaster, total_retroactive_amount, processed_orders.count)
    else
      Rails.logger.info "No retroactive payments to process for contractor #{contractor_id}"
    end

    total_retroactive_amount
  end
end
