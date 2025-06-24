class RewardPayoutJob < ApplicationJob
  queue_as :default

  def perform(reward_payout_id)
    reward_payout = RewardPayout.find(reward_payout_id)
    user = reward_payout.user

    # Validate reward payout can be processed
    unless reward_payout.pending?
      Rails.logger.error "Cannot process reward payout #{reward_payout_id}: Status is #{reward_payout.status}"
      return
    end

    # Validate user has a valid PayPal email for payout
    recipient_email = user.payout_paypal_email
    unless recipient_email.present? && valid_email?(recipient_email)
      error_message = if user.role == 'skillmaster'
                        'Contractor PayPal email not configured or verified'
                      else
                        'Customer PayPal email not configured or verified'
                      end
      reward_payout.mark_as_failed!(error_message)
      Rails.logger.error "Cannot process reward payout #{reward_payout_id}: #{error_message}"
      return
    end

    begin
      # Process PayPal payout
      paypal_service = PaypalService.new
      payout_result = paypal_service.create_payout(
        recipient_email: recipient_email,
        amount: reward_payout.amount,
        currency: 'USD',
        note: "#{reward_payout.title} - RavenBoost Reward",
        sender_item_id: "reward_payout_#{reward_payout.id}"
      )

      if payout_result.successful?
        # Update payout record with PayPal details
        reward_payout.mark_as_processing!(
          payout_result.batch_id,
          payout_result.item_id
        )

        Rails.logger.info "Reward payout initiated for user #{user.id}: $#{reward_payout.amount} (#{reward_payout.payout_type}) - Batch: #{payout_result.batch_id}"

      else
        reward_payout.mark_as_failed!(payout_result.error_message)
        Rails.logger.error "Failed to initiate reward payout for user #{user.id}: #{payout_result.error_message}"

        # Notify admin of payout failure
        AdminMailer.reward_payout_failed(user, reward_payout.amount, reward_payout.payout_type,
                                         payout_result.error_message).deliver_now
      end
    rescue StandardError => e
      Rails.logger.error "Exception processing reward payout for user #{user.id}: #{e.message}"

      # Mark payout as failed
      reward_payout.mark_as_failed!(e.message)

      # Notify admin of exception
      AdminMailer.reward_payout_failed(user, reward_payout.amount, reward_payout.payout_type, e.message).deliver_now
    end
  end

  private

  def valid_email?(email)
    email =~ URI::MailTo::EMAIL_REGEXP
  end
end
