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

  has_many :bug_reports, dependent: :destroy
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

