class CreatePaypalOrderJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)

    # Skip if PayPal order already exists
    return if order.paypal_order_id.present?

    begin
      # Create PayPal order
      paypal_service = PaypalService.new
      paypal_order = paypal_service.create_order(
        amount: order.total_price,
        currency: 'USD',
        reference_id: order.internal_id,
        description: "RavenBoost Order ##{order.internal_id}"
      )

      # Update order with PayPal order ID
      order.update!(
        paypal_order_id: paypal_order.id,
        paypal_payment_status: 'created'
      )

      Rails.logger.info "PayPal order created for Order #{order.id}: #{paypal_order.id}"
    rescue StandardError => e
      Rails.logger.error "Failed to create PayPal order for Order #{order.id}: #{e.message}"

      # Optionally send notification to admin
      AdminMailer.paypal_order_creation_failed(order, e.message).deliver_now
    end
  end
end
