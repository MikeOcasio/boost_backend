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
  has_many :user_rewards, dependent: :destroy
  has_many :referrals, class_name: 'Order', foreign_key: 'referral_user_id'
  has_many :reviews, dependent: :destroy
  has_many :received_reviews, as: :reviewable, class_name: 'Review'
  has_many :written_reviews, class_name: 'Review'
  has_one :contractor, dependent: :destroy
  has_many :payment_approvals, foreign_key: 'admin_user_id', dependent: :destroy

  # Constants
  # ---------------
  ROLE_LIST = %w[admin skillmaster customer skillcoach coach dev c_support manager].freeze

  # Country and currency mappings
  COUNTRY_CURRENCY_MAP = {
    'US' => 'USD',
    'CA' => 'CAD',
    'GB' => 'GBP',
    'AU' => 'AUD',
    'DE' => 'EUR',
    'FR' => 'EUR',
    'IT' => 'EUR',
    'ES' => 'EUR',
    'NL' => 'EUR',
    'JP' => 'JPY',
    'KR' => 'KRW',
    'BR' => 'BRL',
    'MX' => 'MXN',
    'IN' => 'INR',
    'SG' => 'SGD',
    'HK' => 'HKD'
  }.freeze

  COUNTRY_REGIONS = {
    'US' => 'North America',
    'CA' => 'North America',
    'MX' => 'North America',
    'GB' => 'Europe',
    'DE' => 'Europe',
    'FR' => 'Europe',
    'IT' => 'Europe',
    'ES' => 'Europe',
    'NL' => 'Europe',
    'AU' => 'Asia Pacific',
    'SG' => 'Asia Pacific',
    'HK' => 'Asia Pacific',
    'JP' => 'Asia',
    'KR' => 'Asia',
    'IN' => 'Asia',
    'BR' => 'Latin America'
  }.freeze

  # Validations
  # ---------------
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLE_LIST }
  validates :country, inclusion: { in: COUNTRY_CURRENCY_MAP.keys }, allow_blank: true
  validate :password_complexity

  # Callbacks
  before_validation :set_default_role, on: :create
  before_save :set_currency_from_country, if: :country_changed?

  scope :active, -> { where(deleted_at: nil) }
  scope :skillmaster, -> { where(role: 'skillmaster') }

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
    if Rails.env.development? || Rails.env.test?
      host = 'localhost:3000'
      protocol = 'http'
    else
      host = 'ravenboost.com' # Production domain
      protocol = 'https'
    end

    "#{protocol}://#{host}?ref=#{id}"
  end

  def completion_points
    total_completion_points
  end

  def available_completion_points
    read_attribute(:available_completion_points) || 0
  end

  def referral_points
    total_referral_points
  end

  def available_referral_points
    read_attribute(:available_referral_points) || 0
  end

  def deduct_points(amount, type)
    case type
    when 'completion'
      update!(available_completion_points: available_completion_points - amount)
    when 'referral'
      update!(available_referral_points: available_referral_points - amount)
    end
  end

  def next_completion_reward
    UserReward.calculate_next_threshold(completion_points, 'completion')
  end

  def next_referral_reward
    UserReward.calculate_next_threshold(referral_points, 'referral')
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

  # Role helper methods
  def customer?
    role == 'customer'
  end

  def skillmaster?
    role == 'skillmaster'
  end

  def admin?
    role == 'admin'
  end

  def dev?
    role == 'dev'
  end

  def c_support?
    role == 'c_support'
  end

  def manager?
    role == 'manager'
  end

  def staff?
    skillmaster? || admin? || dev? || c_support? || manager?
  end

  # Check if user can have a contractor account
  def can_have_contractor_account?
    skillmaster? || admin? || dev?
  end

  # Ensure contractor account exists for eligible users
  def ensure_contractor_account!
    return unless can_have_contractor_account?
    return if contractor.present?

    create_contractor!
  end

  # Currency and country helper methods
  def user_currency
    return currency if currency.present?
    return COUNTRY_CURRENCY_MAP[country] if country.present?

    'USD' # Default fallback
  end

  def region_name
    COUNTRY_REGIONS[country] || 'International'
  end

  def paypal_locale
    return 'en-US' unless country.present?

    locale_map = {
      'US' => 'en-US',
      'CA' => 'en-CA',
      'GB' => 'en-GB',
      'AU' => 'en-AU',
      'DE' => 'de-DE',
      'FR' => 'fr-FR',
      'IT' => 'it-IT',
      'ES' => 'es-ES',
      'NL' => 'nl-NL',
      'JP' => 'ja-JP',
      'KR' => 'ko-KR',
      'BR' => 'pt-BR',
      'MX' => 'es-MX',
      'IN' => 'en-IN',
      'SG' => 'en-SG',
      'HK' => 'en-HK'
    }

    locale_map[country] || 'en-US'
  end

  private

  def set_currency_from_country
    return unless country.present?

    self.currency = COUNTRY_CURRENCY_MAP[country]
    self.region = COUNTRY_REGIONS[country]
  end
end
