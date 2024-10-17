# app/mailers/test_mailer.rb
class TestMailer < ApplicationMailer
  def welcome_email(email:, name:)
    @user = OpenStruct.new(email: email, name: name)
    mail(to: @user.email, subject: 'Welcome to RavenBoost!')
  end
end

