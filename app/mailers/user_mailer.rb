# app/mailers/user_mailer.rb

class UserMailer < ApplicationMailer
  def otp(user, otp)
    @user = user
    @otp = otp
    mail(to: @user.email, subject: 'Your OTP')
  end
end
