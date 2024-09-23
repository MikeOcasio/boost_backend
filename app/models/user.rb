# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  email                  :string           not null
#  password_digest        :string           not null
#  first_name             :string
#  last_name              :string
#  role                   :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  encrypted_data         :text
#  encrypted_symmetric_key :text
#
# Model for representing users in the application.
class User < ApplicationRecord
  devise :two_factor_authenticatable
  # include Devise::Models::TwoFactorAuthenticatable
  # include Devise::Models::TwoFactorBackupable

  #add Devise modules
  devise :database_authenticatable,
  :registerable,
  :recoverable,
  :rememberable,
  :trackable,
  :validatable,
  # :confirmable,
  # :lockable,
  # :timeoutable,
  # :two_factor_authenticatable,
  :jwt_authenticatable,
  jwt_revocation_strategy: JwtDenylist


  # :two_factor_backupable

  has_many :orders
  has_many :carts
  has_many :notifications
  has_many :preferred_skill_masters
  has_many :preferred_skill_masters_users, through: :preferred_skill_masters, source: :user
  has_many :platform_credentials, dependent: :destroy

  # ---------------
  ROLE_LIST = ["admin", "skillmaster", "customer", "skillcoach", "coach", "dev"].freeze

  # Validations
  # ---------------
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLE_LIST }
  validate :password_complexity

  # Methods
  # ---------------

  def password_complexity
    return if password.blank? || password =~ /^(?=.*?[A-Z])(?=.*?[!@#$&*]).{8,}$/

    errors.add :password, 'Complexity requirement not met. Please use: 8 characters, at least one uppercase letter and one special character'
  end

  def timeout_in
    30.minutes
  end

  def maximum_attempts
    if self.failed_attempts >= 3
      1
    else
      3
    end
  end

  def unlock_in
    if self.failed_attempts >= 3
      10.minutes
    else
      5.minutes
    end
  end

  def jwt_token
    Warden::JWTAuth::UserEncoder.new.call(self, :user, nil).first
  end


end




# Here's a ranking of the Devise modules from least complex to most complex, based on the amount of setup required and the functionality they provide:

# 1. `:database_authenticatable`: This is the simplest module. It handles password storage and user authentication during sign-in.

# 2. `:validatable`: Provides basic validations for email and password. It's optional and can be customized, so you're able to define your own validations.

# 3. `:registerable`: Handles user registration, as well as allowing users to edit and destroy their account. Requires additional routes and views for the registration process.

# 4. `:rememberable`: Manages a token for remembering the user from a saved cookie. Requires a `remember_created_at` field in your `User` model.

# 5. `:recoverable`: Adds the ability to reset the user's password and sends reset instructions. Requires additional routes and views, and also setup for sending emails.

# 6. `:trackable`: Tracks sign in count, timestamps, and IP address. Requires additional fields in your `User` model.

# 7. `:timeoutable`: Expires sessions that have no activity in a specified period of time. Requires a `timeout_in` method in your `User` model.

# 8. `:confirmable`: Sends emails with confirmation instructions and verifies whether an account is already confirmed during sign in. Requires additional routes and views, and also setup for sending emails.

# 9. `:lockable`: Locks an account after a specified number of failed sign-in attempts. Requires additional fields in your `User` model.

# 10. `:two_factor_authenticatable`: Handles two-factor authentication with a secondary code. Requires additional setup for generating and verifying the secondary code.

# 11. `:two_factor_backupable`: Handles backup codes for two-factor authentication. Requires additional setup for generating and verifying the backup codes.

# Please note that the complexity can vary depending on your specific application requirements and the customizations you might need to make to each module.
