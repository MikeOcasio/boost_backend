class PaypalPayoutJob < ApplicationJob
  queue_as :default

  def perform(contractor_id, amount)
    contractor = Contractor.find(contractor_id)

    # Validate contractor can receive payouts
    unless contractor.can_receive_payouts?
      Rails.logger.error "Cannot process PayPal payout for contractor #{contractor_id}: Account not ready or tax non-compliant"
      return
    end

    # Check if contractor has sufficient available balance
    if contractor.available_balance < amount
      Rails.logger.error "Cannot process PayPal payout for contractor #{contractor_id}: Insufficient balance (requested: $#{amount}, available: $#{contractor.available_balance})"
      return
    end

    begin
      # Create payout record
      payout = contractor.paypal_payouts.create!(
        amount: amount,
        status: 'pending'
      )

      # Process PayPal payout
      paypal_service = PaypalService.new
      payout_result = paypal_service.create_payout(
        recipient_email: contractor.paypal_payout_email,
        amount: amount,
        currency: 'USD',
        note: 'RavenBoost earnings payout',
        sender_item_id: "payout_#{payout.id}"
      )

      if payout_result.successful?
        # Update payout record with PayPal details
        payout.mark_as_processing!(
          payout_result.batch_id,
          payout_result.item_id
        )

        # Deduct amount from contractor's available balance
        contractor.update!(
          available_balance: contractor.available_balance - amount,
          last_withdrawal_at: Time.current
        )

        Rails.logger.info "PayPal payout initiated for contractor #{contractor_id}: $#{amount} (Batch: #{payout_result.batch_id})"

      else
        payout.mark_as_failed!(payout_result.error_message, payout_result.response_data)
        Rails.logger.error "Failed to initiate PayPal payout for contractor #{contractor_id}: #{payout_result.error_message}"

        # Notify admin of payout failure
        AdminMailer.paypal_payout_failed(contractor, amount, payout_result.error_message).deliver_now
      end
    rescue StandardError => e
      Rails.logger.error "Exception processing PayPal payout for contractor #{contractor_id}: #{e.message}"

      # Mark payout as failed if it was created
      payout&.mark_as_failed!(e.message)

      # Notify admin of exception
      AdminMailer.paypal_payout_failed(contractor, amount, e.message).deliver_now
    end
  end
end
