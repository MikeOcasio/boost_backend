# app/mailers/user_mailer.rb

class UserMailer < ApplicationMailer
  default from: 'support@bot.ravenboost.com'

  def otp(user, otp)
    @user = user
    @otp = otp
    mail(to: @user.email, subject: 'Your OTP')
  end
end
