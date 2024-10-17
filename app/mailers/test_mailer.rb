# app/mailers/test_mailer.rb
class TestMailer < ApplicationMailer
  def welcome_email
    @user = OpenStruct.new(email: "test@example.com", name: "John Doe")
    mail(to: @user.email, subject: 'Welcome to RavenBoost!')
  end
end
