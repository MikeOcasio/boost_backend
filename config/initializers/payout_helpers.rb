# Load PayoutHelpers in Rails console for easy testing
if defined?(Rails::Console)
  require_relative '../lib/payout_helpers'

  puts "\n" + "=" * 60
  puts "🔧 PayPal Payout Testing Tools Loaded!"
  puts "=" * 60
  puts
  puts "Available helper methods:"
  puts "  📊 PayoutHelpers.check_all_payouts"
  puts "  🔄 PayoutHelpers.sync_payout_status(id)"
  puts "  🔗 PayoutHelpers.sync_all_payouts"
  puts "  🧪 PayoutHelpers.create_test_payout(contractor_id, amount)"
  puts "  🔍 PayoutHelpers.show_payout_details(id)"
  puts
  puts "Quick start:"
  puts "  # Check current contractors:"
  puts "  Contractor.all.each { |c| puts \"\#{c.id}: \#{c.user.first_name} - \#{c.paypal_payout_email}\" }"
  puts
  puts "  # Create a test payout:"
  puts "  PayoutHelpers.create_test_payout(1, 25.00)"
  puts
  puts "  # Check all payout statuses:"
  puts "  PayoutHelpers.check_all_payouts"
  puts
  puts "=" * 60
end
