module PayoutHelpers
  def self.check_all_payouts
    puts "📊 PayPal Payout Status Summary"
    puts "=" * 50

    if PaypalPayout.count == 0
      puts "No payouts found in database."
      return
    end

    PaypalPayout.includes(contractor: :user).order(:created_at).each do |payout|
      contractor_name = "#{payout.contractor.user.first_name} #{payout.contractor.user.last_name}"

      puts "#{payout.id}: #{contractor_name} - $#{payout.amount} - #{payout.status}"
      puts "  Email: #{payout.contractor.paypal_payout_email}"
      puts "  Batch ID: #{payout.paypal_payout_batch_id}"
      puts "  Item ID: #{payout.paypal_payout_item_id}" if payout.paypal_payout_item_id
      puts "  Created: #{payout.created_at}"
      puts "  Updated: #{payout.updated_at}"

      if payout.failure_reason.present?
        puts "  ❌ Failure: #{payout.failure_reason}"
      end

      puts "-" * 30
    end

    puts "\n📈 Summary:"
    puts "Total: #{PaypalPayout.count}"
    puts "Pending: #{PaypalPayout.where(status: 'pending').count}"
    puts "Processing: #{PaypalPayout.where(status: 'processing').count}"
    puts "Success: #{PaypalPayout.where(status: 'success').count}"
    puts "Failed: #{PaypalPayout.where(status: 'failed').count}"
    puts "Total Amount: $#{PaypalPayout.sum(:amount)}"
    puts "Successful Amount: $#{PaypalPayout.where(status: 'success').sum(:amount)}"
  end

  def self.sync_payout_status(payout_id)
    payout = PaypalPayout.find(payout_id)

    if payout.paypal_payout_batch_id.blank?
      puts "❌ No PayPal batch ID found for payout #{payout.id}"
      return false
    end

    puts "🔄 Checking PayPal status for payout #{payout.id}..."

    status_result = PaypalService.get_payout_status(payout.paypal_payout_batch_id, payout.paypal_payout_item_id)

    puts "📡 PayPal API Response:"
    puts "  Success: #{status_result[:success]}"
    puts "  Status: #{status_result[:status]}"
    puts "  Error: #{status_result[:error]}" if status_result[:error]

    if status_result[:success] && status_result[:status].present?
      old_status = payout.status

      if old_status != status_result[:status]
        payout.update!(
          status: status_result[:status],
          paypal_response: status_result[:response]
        )
        puts "✅ Updated payout #{payout.id} from '#{old_status}' to '#{status_result[:status]}'"
      else
        puts "ℹ️  Status unchanged: '#{old_status}'"
      end
    else
      puts "❌ Failed to get status from PayPal"
    end

    status_result[:success]
  end

  def self.sync_all_payouts
    puts "🔄 Syncing all payouts with PayPal..."

    payouts_with_batch_id = PaypalPayout.where.not(paypal_payout_batch_id: nil)

    if payouts_with_batch_id.count == 0
      puts "No payouts with PayPal batch IDs found."
      return
    end

    updated_count = 0
    error_count = 0

    payouts_with_batch_id.each do |payout|
      print "Checking payout #{payout.id}... "

      begin
        status_result = PaypalService.get_payout_status(payout.paypal_payout_batch_id, payout.paypal_payout_item_id)

        if status_result[:success] && status_result[:status].present?
          old_status = payout.status

          if old_status != status_result[:status]
            payout.update!(
              status: status_result[:status],
              paypal_response: status_result[:response]
            )
            puts "✅ Updated: #{old_status} → #{status_result[:status]}"
            updated_count += 1
          else
            puts "✓ No change: #{old_status}"
          end
        else
          puts "❌ Error: #{status_result[:error]}"
          error_count += 1
        end
      rescue => e
        puts "❌ Exception: #{e.message}"
        error_count += 1
      end
    end

    puts "\n📊 Sync Summary:"
    puts "Checked: #{payouts_with_batch_id.count}"
    puts "Updated: #{updated_count}"
    puts "Errors: #{error_count}"
  end

  def self.create_test_payout(contractor_id, amount = 10.00)
    contractor = Contractor.find(contractor_id)

    puts "🧪 Creating test payout..."
    puts "Contractor: #{contractor.user.first_name} #{contractor.user.last_name}"
    puts "Email: #{contractor.paypal_payout_email}"
    puts "Amount: $#{amount}"

    unless contractor.can_receive_payouts?
      puts "❌ Contractor cannot receive payouts (missing verified PayPal email)"
      return false
    end

    if contractor.available_balance < amount
      puts "❌ Insufficient balance (available: $#{contractor.available_balance})"
      return false
    end

    begin
      PaypalPayoutJob.perform_now(contractor.id, amount)
      puts "✅ Test payout job executed successfully"

      # Check the latest payout for this contractor
      latest_payout = contractor.paypal_payouts.order(:created_at).last
      if latest_payout
        puts "📝 Payout Record ID: #{latest_payout.id}"
        puts "   Status: #{latest_payout.status}"
        puts "   Batch ID: #{latest_payout.paypal_payout_batch_id}"
      end

      true
    rescue => e
      puts "❌ Error creating test payout: #{e.message}"
      false
    end
  end

  def self.show_payout_details(payout_id)
    payout = PaypalPayout.find(payout_id)
    contractor = payout.contractor
    user = contractor.user

    puts "💰 Payout Details - ID: #{payout.id}"
    puts "=" * 40
    puts "Contractor: #{user.first_name} #{user.last_name}"
    puts "Email: #{contractor.paypal_payout_email}"
    puts "Amount: $#{payout.amount}"
    puts "Status: #{payout.status}"
    puts "Created: #{payout.created_at}"
    puts "Updated: #{payout.updated_at}"
    puts ""
    puts "PayPal Information:"
    puts "  Batch ID: #{payout.paypal_payout_batch_id || 'None'}"
    puts "  Item ID: #{payout.paypal_payout_item_id || 'None'}"
    puts ""

    if payout.failure_reason.present?
      puts "❌ Failure Reason: #{payout.failure_reason}"
      puts ""
    end

    if payout.paypal_response.present?
      puts "📡 PayPal Response:"
      puts JSON.pretty_generate(payout.paypal_response)
    end

    # Get live status from PayPal if we have batch ID
    if payout.paypal_payout_batch_id.present?
      puts "\n🔍 Live PayPal Status Check:"
      status_result = PaypalService.get_payout_status(payout.paypal_payout_batch_id, payout.paypal_payout_item_id)

      if status_result[:success]
        puts "  Live Status: #{status_result[:status]}"
        puts "  Database Status: #{payout.status}"

        if status_result[:status] != payout.status
          puts "  ⚠️  Status mismatch detected!"
        end
      else
        puts "  ❌ Could not fetch live status: #{status_result[:error]}"
      end
    end
  end
end

# Auto-load this module when Rails starts
if defined?(Rails) && Rails.env.development?
  puts "💡 PayoutHelpers loaded! Available methods:"
  puts "   PayoutHelpers.check_all_payouts"
  puts "   PayoutHelpers.sync_payout_status(id)"
  puts "   PayoutHelpers.sync_all_payouts"
  puts "   PayoutHelpers.create_test_payout(contractor_id, amount)"
  puts "   PayoutHelpers.show_payout_details(id)"
end
