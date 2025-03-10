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
  devise :two_factor_authenticatable,
         :database_authenticatable,
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
  has_many :orders, dependent: :nullify
  has_many :notifications, dependent: :nullify
  has_many :preferred_skill_masters, dependent: :nullify
  has_many :preferred_skill_masters_users, through: :preferred_skill_masters, source: :user, dependent: :nullify # Add dependent: :nullify here
  has_many :platform_credentials, dependent: :destroy
  has_many :users_categories, dependent: :nullify
  has_many :categories, through: :users_categories, dependent: :nullify
  has_many :skillmaster_rewards
  has_many :referrals, class_name: 'Order', foreign_key: 'referral_skillmaster_id'
  has_many :reviews, dependent: :destroy
  has_many :received_reviews, as: :reviewable, class_name: 'Review'
  has_many :written_reviews, class_name: 'Review'

  before_validation :set_default_role, on: :create
  # ---------------
  ROLE_LIST = %w[admin skillmaster customer skillcoach coach dev].freeze

  # Validations
  # ---------------
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLE_LIST }
  validate :password_complexity

  scope :active, -> { where(deleted_at: nil) }

  # Methods
  # ---------------

  def sub_platforms_info
    platforms_with_subs = platforms.includes(:sub_platforms, :platform_credentials)

    filtered_sub_platforms = platforms_with_subs.flat_map do |platform|
      platform.sub_platforms.select do |sub|
        # Only include sub-platforms that have a matching platform credential for the user
        platform_credentials.exists?(sub_platform_id: sub.id, user_id: id)
      end
    end

    filtered_sub_platforms.map { |sub| { id: sub.id, name: sub.name } }
  end

  # Two-factor authentication configuration
  # This uses the ROTP gem under the hood (part of devise-two-factor)
  def need_two_factor_authentication?(_request)
    # Only require 2FA if the user has opted in
    otp_required_for_login && otp_setup_complete
  end

  # Ensure user has a OTP secret
  def generate_otp_secret_if_missing!
    return if otp_secret.present?

    self.otp_secret = User.generate_otp_secret
    save!
  end

  def password_complexity
    return if password.blank?

    errors.delete(:password)

    # Check length
    errors.add :password, 'Must be at least 8 characters long.' if password.length < 8

    # Check for uppercase letter
    errors.add :password, 'Must contain at least one uppercase letter.' unless password =~ /[A-Z]/

    # Check for special character
    return if password =~ /[!@#{::Regexp.last_match(0)}*]/

    errors.add :password, 'Must contain at least one special character.'
  end

  def valid_password?(password)
    # Return false if the user is marked as deleted
    return false if deleted?

    super
  end

  def set_default_role
    self.role ||= 'customer'
  end

  def lock_access!(opts = { send_instructions: true })
    if locked_by_admin
      update!(locked_at: Time.current)
    else
      super
    end
  end

  def unlock_access!
    if locked_by_admin
      update!(locked_at: nil)
      update!(locked_by_admin: false)
    else
      super
    end
  end

  def send_unlock_instructions
    return if locked_by_admin

    super
  end

  def deleted?
    deleted_at.present?
  end

  # Add a column to store the preferred 2FA method
  def two_factor_method
    read_attribute(:two_factor_method) || 'email' # Default to email if not set
  end

  def send_two_factor_authentication_code
    UserMailer.otp(self, current_otp).deliver_now
  end

  def referral_link
    # Generate unique referral link
    "#{Rails.application.routes.url_helpers.root_url}?ref=#{id}"
  end

  def completion_points
    # Calculate points based on completed orders
    completed_orders.sum(:points)
  end

  def referral_points
    # Calculate points from valid referrals (orders >= $10)
    referrals.where('total >= ?', 10.00).count * 10
  end

  def next_completion_reward
    SkillmasterReward.calculate_next_threshold(completion_points, 'completion')
  end

  def next_referral_reward
    SkillmasterReward.calculate_next_threshold(referral_points, 'referral')
  end

  def can_review?(target)
    case target
    when User
      if role == 'skillmaster'
        target.role == 'customer' && Order.exists?(
          state: 'complete',
          user_id: target.id,
          assigned_skill_master_id: id
        )
      elsif role == 'customer'
        target.role == 'skillmaster' && Order.exists?(
          state: 'complete',
          user_id: id,
          assigned_skill_master_id: target.id
        )
      end
    when Order
      target.complete? && (id == target.user_id || id == target.assigned_skill_master_id)
    when Product
      Order.joins(:products)
           .exists?(user_id: id, products: { id: target.id }, state: 'complete')
    else
      false
    end
  end
end
