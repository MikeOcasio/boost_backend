# lib/tasks/email.rake
namespace :email do
  desc "Send welcome email"
  task :send_welcome, [:email, :name] => :environment do |t, args|
    email = args[:email] || "recipient@example.com"
    name = args[:name] || "John Doe"
    TestMailer.welcome_email(email: email, name: name).deliver_now
    puts "Welcome email sent to #{email}!"
  end
end
