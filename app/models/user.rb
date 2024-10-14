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
         :validatable,
         :trackable,
         :lockable,
         :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist



  has_many :user_platforms, dependent: :destroy
  has_many :platforms, through: :user_platforms
  has_many :bug_reports, dependent: :destroy
  has_many :orders
  has_many :carts
  has_many :notifications
  has_many :preferred_skill_masters
  has_many :preferred_skill_masters_users, through: :preferred_skill_masters, source: :user
  has_many :platform_credentials, dependent: :destroy

  before_validation :set_default_role, on: :create
  # ---------------
  ROLE_LIST = ["admin", "skillmaster", "customer", "skillcoach", "coach", "dev"].freeze

  # Validations
  # ---------------
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLE_LIST }
  validate :password_complexity

  scope :active, -> { where(deleted_at: nil) }

  # Methods
  # ---------------

  def password_complexity
    return if password.blank?

    # Check length
    if password.length < 8
      errors.add :password, 'Must be at least 8 characters long.'
    end

    # Check for uppercase letter
    unless password =~ /[A-Z]/
      errors.add :password, 'Must contain at least one uppercase letter.'
    end

    # Check for special character
    unless password =~ /[!@#$&*]/
      errors.add :password, 'Must contain at least one special character.'
    end
  end

  def valid_password?(password)
    # Return false if the user is marked as deleted
    return false if deleted?

    super(password)
  end


  def set_default_role
    self.role ||= "customer"
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


  def lock_access!(opts = { send_instructions: true })
    if locked_by_admin
      update!(locked_at: Time.current)
    else
      super(opts)
    end
  end

  def send_unlock_instructions
    unless locked_by_admin
      super
    end
  end

  def deleted?
    deleted_at.present?
  end
end
