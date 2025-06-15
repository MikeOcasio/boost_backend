class Contractor < ApplicationRecord
  belongs_to :user
  has_many :paypal_payouts, dependent: :destroy

  # Field-level encryption for sensitive tax information
  require 'symmetric_encryption'

  # Define encrypted fields
  ENCRYPTED_FIELDS = %w[
    tax_id
    full_legal_name
    date_of_birth
    address_line_1
    address_line_2
    city
    state_province
    postal_code
  ].freeze

  validates :paypal_payout_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :trolley_recipient_id, uniqueness: true, allow_blank: true
  validates :tax_form_status, inclusion: { in: %w[pending submitted approved rejected] }
  validates :tax_form_type, inclusion: { in: %w[W-9 W-8BEN] }, allow_blank: true
  validates :trolley_account_status, inclusion: { in: %w[pending active suspended] }
  validates :country_code, presence: true, if: :tax_form_submitted?

  after_create :process_retroactive_payments_if_paypal_account_added
  after_update :process_retroactive_payments_if_paypal_account_added

  # International tax information for different countries
  COUNTRY_TAX_INFO = [
    # North America
    {
      code: 'US',
      name: 'United States',
      tax_form: 'W-9',
      tax_id_label: 'SSN or TIN',
      tax_id_format: /^\d{3}-?\d{2}-?\d{4}$|^\d{2}-?\d{7}$/,
      withholding_rate: 0.0,
      payment_methods: ['paypal'],
      requires_date_of_birth: false
    },
    {
      code: 'CA',
      name: 'Canada',
      tax_form: 'W-8BEN',
      tax_id_label: 'Social Insurance Number (SIN)',
      tax_id_format: /^\d{3}[-\s]?\d{3}[-\s]?\d{3}$/,
      withholding_rate: 0.05, # Reduced rate due to tax treaty
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },

    # Europe
    {
      code: 'GB',
      name: 'United Kingdom',
      tax_form: 'W-8BEN',
      tax_id_label: 'National Insurance Number',
      tax_id_format: /^[A-Z]{2}\d{6}[A-Z]$/,
      withholding_rate: 0.0, # Tax treaty
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },
    {
      code: 'DE',
      name: 'Germany',
      tax_form: 'W-8BEN',
      tax_id_label: 'Steuerliche Identifikationsnummer',
      tax_id_format: /^\d{11}$/,
      withholding_rate: 0.05,
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },
    {
      code: 'FR',
      name: 'France',
      tax_form: 'W-8BEN',
      tax_id_label: 'Numéro de Sécurité Sociale',
      tax_id_format: /^\d{13}$/,
      withholding_rate: 0.05,
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },

    # Asia Pacific
    {
      code: 'AU',
      name: 'Australia',
      tax_form: 'W-8BEN',
      tax_id_label: 'Tax File Number (TFN)',
      tax_id_format: /^\d{8,9}$/,
      withholding_rate: 0.05,
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },
    {
      code: 'JP',
      name: 'Japan',
      tax_form: 'W-8BEN',
      tax_id_label: 'My Number',
      tax_id_format: /^\d{12}$/,
      withholding_rate: 0.1,
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },
    {
      code: 'IN',
      name: 'India',
      tax_form: 'W-8BEN',
      tax_id_label: 'Permanent Account Number (PAN)',
      tax_id_format: /^[A-Z]{5}\d{4}[A-Z]$/,
      withholding_rate: 0.25,
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },

    # Latin America
    {
      code: 'BR',
      name: 'Brazil',
      tax_form: 'W-8BEN',
      tax_id_label: 'CPF',
      tax_id_format: /^\d{3}\.\d{3}\.\d{3}-\d{2}$/,
      withholding_rate: 0.3,
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },
    {
      code: 'MX',
      name: 'Mexico',
      tax_form: 'W-8BEN',
      tax_id_label: 'RFC',
      tax_id_format: /^[A-Z]{4}\d{6}[A-Z0-9]{3}$/,
      withholding_rate: 0.1,
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    },

    # Global fallback for any other country
    {
      code: 'OTHER',
      name: 'Other Country',
      tax_form: 'W-8BEN',
      tax_id_label: 'National Tax ID',
      tax_id_format: nil, # No validation for unknown formats
      withholding_rate: 0.3, # Default US withholding
      payment_methods: ['paypal'],
      requires_date_of_birth: true
    }
  ].freeze

  # Encryption methods for sensitive fields
  def self.encryption_key
    @encryption_key ||= Rails.application.credentials.dig(:encryption, :contractor_key) ||
                        Rails.application.secrets.contractor_encryption_key ||
                        ENV['CONTRACTOR_ENCRYPTION_KEY'] ||
                        raise('Contractor encryption key not configured')
  end

  # Generate virtual attributes for encrypted fields
  ENCRYPTED_FIELDS.each do |field|
    # Define getter method that decrypts the data
    define_method(field) do
      encrypted_value = self["encrypted_#{field}"]
      return nil if encrypted_value.blank?

      begin
        SymmetricEncryption.decrypt(encrypted_value, self.class.encryption_key)
      rescue StandardError => e
        Rails.logger.error "Failed to decrypt #{field} for contractor #{id}: #{e.message}"
        nil
      end
    end

    # Define setter method that encrypts the data
    define_method("#{field}=") do |value|
      if value.blank?
        self["encrypted_#{field}"] = nil
      else
        encrypted_value = SymmetricEncryption.encrypt(value.to_s, self.class.encryption_key)
        self["encrypted_#{field}"] = encrypted_value
      end
    end

    # Define presence check method
    define_method("#{field}?") do
      self["encrypted_#{field}"].present?
    end
  end

  # Method to safely log contractor info without exposing sensitive data
  def safe_log_info
    {
      id: id,
      user_id: user_id,
      country_code: country_code,
      tax_form_status: tax_form_status,
      tax_form_type: tax_form_type,
      paypal_email_verified: paypal_email_verified?,
      has_tax_id: tax_id?,
      has_legal_name: full_legal_name?,
      has_address: address_line_1?
    }
  end

  # Method to validate required encrypted fields based on country
  def validate_required_encrypted_fields
    errors = []

    # All countries require tax_id and full_legal_name
    errors << 'Tax ID is required' unless tax_id?
    errors << 'Full legal name is required' unless full_legal_name?

    # Non-US countries require date of birth
    if country_code != 'US' && requires_date_of_birth? && !date_of_birth?
      errors << "Date of birth is required for #{country_info[:name]} contractors"
    end

    # Address validation for international contractors
    if country_code != 'US'
      errors << 'Address line 1 is required' unless address_line_1?
      errors << 'City is required' unless city?
      errors << 'Postal code is required' unless postal_code?
    end

    errors
  end

  # International contractor methods
  def self.country_info(country_code)
    COUNTRY_TAX_INFO.find { |c| c[:code] == country_code&.upcase } ||
      COUNTRY_TAX_INFO.find { |c| c[:code] == 'OTHER' }
  end

  def country_info
    @country_info ||= self.class.country_info(country_code || 'OTHER')
  end

  def required_tax_form_type
    country_info[:tax_form]
  end

  def tax_id_label
    country_info[:tax_id_label]
  end

  def expected_withholding_rate
    country_info[:withholding_rate]
  end

  def available_payment_methods
    country_info[:payment_methods]
  end

  def requires_date_of_birth?
    country_info[:requires_date_of_birth]
  end

  def validate_tax_id_format(tax_id)
    format_regex = country_info[:tax_id_format]
    return true if format_regex.nil? # No validation for unknown countries

    tax_id&.match?(format_regex)
  end

  def tax_form_submitted?
    tax_form_status.present? && tax_form_status != 'pending'
  end

  # Calculate net payout after withholding
  def calculate_net_payout(gross_amount)
    withholding_amount = gross_amount * (withholding_rate || expected_withholding_rate)
    net_amount = gross_amount - withholding_amount

    {
      gross_amount: gross_amount.to_f,
      withholding_amount: withholding_amount.to_f,
      net_amount: net_amount.to_f,
      withholding_rate: (withholding_rate || expected_withholding_rate).to_f
    }
  end

  # Override existing method to include country requirements
  def can_receive_payouts?
    paypal_payout_email.present? &&
      tax_form_status == 'approved' &&
      country_code.present? &&
      (country_code == 'US' || paypal_email_verified?)
  end

  # Submit tax form for verification
  def submit_tax_form!(form_type, form_data)
    # Validate required fields before submission
    validation_errors = validate_required_encrypted_fields
    raise ArgumentError, "Missing required fields: #{validation_errors.join(', ')}" if validation_errors.any?

    # Validate tax ID format for the contractor's country
    unless validate_tax_id_format(tax_id)
      raise ArgumentError, "Invalid #{tax_id_label} format for #{country_info[:name]}"
    end

    # Update form status (remove tax_form_data since it doesn't exist in schema)
    update!(
      tax_form_type: form_type,
      tax_form_status: 'submitted'
    )

    # Queue job to verify tax form with appropriate service
    TrolleyTaxVerificationJob.perform_later(id, safe_tax_form_data_for_verification)

    Rails.logger.info "Tax form #{form_type} submitted for contractor #{id} from #{country_info[:name]}"
  end

  # Prepare safe tax form data for verification (encrypted fields are decrypted only for API calls)
  def safe_tax_form_data_for_verification
    {
      tax_id: tax_id,
      full_legal_name: full_legal_name,
      date_of_birth: date_of_birth,
      address_line_1: address_line_1,
      address_line_2: address_line_2,
      city: city,
      state_province: state_province,
      postal_code: postal_code,
      country_code: country_code,
      tax_form_type: tax_form_type
    }.compact
  end

  # Methods for tax form status management
  def approve_tax_form!
    update!(
      tax_form_status: 'approved',
      trolley_account_status: 'active'
    )
  end

  def reject_tax_form!
    update!(tax_form_status: 'rejected')
  end

  # Withdrawal cooldown configuration
  WITHDRAWAL_COOLDOWN_DAYS = 7

  # Basic balance and withdrawal methods
  def can_withdraw?
    return true if last_withdrawal_at.nil?

    last_withdrawal_at < WITHDRAWAL_COOLDOWN_DAYS.days.ago
  end

  def days_until_next_withdrawal
    return 0 if can_withdraw?

    WITHDRAWAL_COOLDOWN_DAYS - (Date.current - last_withdrawal_at.to_date).to_i
  end

  def add_to_available_balance(amount)
    increment!(:available_balance, amount)
    increment!(:total_earned, amount)
  end

  def add_to_pending_balance(amount)
    increment!(:pending_balance, amount)
    # NOTE: total_earned is only updated when admin approves and moves to available balance
  end

  def move_pending_to_available
    return 0 if pending_balance <= 0

    amount = pending_balance
    transaction do
      update!(
        available_balance: available_balance + amount,
        pending_balance: 0,
        total_earned: total_earned + amount
      )
      # total_earned is incremented here since this represents admin-approved earnings
    end
    amount
  end

  def approve_and_move_to_available(amount)
    return 0 if pending_balance < amount

    transaction do
      update!(
        available_balance: available_balance + amount,
        pending_balance: pending_balance - amount,
        total_earned: total_earned + amount
      )

      # Check tax compliance before processing payout
      if paypal_account_ready? && tax_compliant?
        PaypalPayoutJob.perform_later(id, amount)
      else
        Rails.logger.warn "Contractor #{id} earnings approved but account not ready - payout will be processed when requirements are met"
      end
    end
    amount
  end

  # Check if contractor has a valid PayPal account and tax compliance
  def paypal_account_ready?
    paypal_payout_email.present? && trolley_account_status == 'active'
  end

  # Process retroactive payments when PayPal account is added
  def process_retroactive_payments_if_paypal_account_added
    # Handle both create (new contractor with paypal_payout_email) and update (adding paypal_payout_email to existing contractor)
    paypal_account_added = if persisted? && saved_changes.key?('paypal_payout_email')
                             # Update case: paypal_payout_email was changed
                             saved_change_to_paypal_payout_email? && paypal_payout_email.present?
                           else
                             # Create case: new record with paypal_payout_email
                             paypal_payout_email.present?
                           end

    return unless paypal_account_added

    Rails.logger.info "PayPal account added for contractor #{id} (user: #{user_id}). Processing retroactive payments..."

    # Queue job to process retroactive payments
    ProcessRetroactivePaymentsJob.perform_later(id)
  end

  # Check if contractor has required tax compliance
  def tax_compliant?
    tax_form_status == 'approved' && tax_form_type.present?
  end
end
