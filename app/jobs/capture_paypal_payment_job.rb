class CapturePaypalPaymentJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Validate that payment can be captured
    unless order.paypal_order_id.present?
      Rails.logger.error "Cannot capture PayPal payment for Order #{order.id}: No PayPal order ID"
      return
    end

    unless order.payment_approval&.approved?
      Rails.logger.error "Cannot capture PayPal payment for Order #{order.id}: Payment not approved"
      return
    end

    begin
      # Capture the PayPal payment
      paypal_service = PaypalService.new
      capture_result = paypal_service.capture_order(order.paypal_order_id)

      if capture_result.successful?
        # Update order with capture details
        order.update!(
          paypal_capture_id: capture_result.capture_id,
          paypal_payment_status: 'captured'
        )

        # Move skillmaster earnings from pending to available
        if order.assigned_skill_master&.contractor
          order.assigned_skill_master.contractor.approve_and_move_to_available(order.skillmaster_earned)
        end

        Rails.logger.info "PayPal payment captured for Order #{order.id}: #{capture_result.capture_id}"

      else
        order.update!(paypal_payment_status: 'failed')
        Rails.logger.error "Failed to capture PayPal payment for Order #{order.id}: #{capture_result.error_message}"

        # Notify admin of capture failure
        AdminMailer.paypal_capture_failed(order, capture_result.error_message).deliver_now
      end
    rescue StandardError => e
      order.update!(paypal_payment_status: 'failed')
      Rails.logger.error "Exception capturing PayPal payment for Order #{order.id}: #{e.message}"

      # Notify admin of exception
      AdminMailer.paypal_capture_failed(order, e.message).deliver_now
    end
  end
end
