class TrolleyTaxVerificationJob < ApplicationJob
  queue_as :default

  def perform(contractor_id, form_data = {})
    contractor = Contractor.find(contractor_id)

    begin
      # Initialize Trolley service
      trolley_service = TrolleyService.new

      # Create or update Trolley recipient
      if contractor.trolley_recipient_id.present?
        # Update existing recipient
        trolley_service.update_recipient(
          contractor.trolley_recipient_id,
          build_recipient_data(contractor, form_data)
        )
      else
        # Create new recipient
        recipient = trolley_service.create_recipient(
          build_recipient_data(contractor, form_data)
        )

        # Store Trolley recipient ID
        contractor.update!(trolley_recipient_id: recipient.id)
      end

      # Submit tax form for verification
      tax_verification = trolley_service.submit_tax_form(
        contractor.trolley_recipient_id,
        contractor.tax_form_type,
        form_data
      )

      if tax_verification.successful?
        contractor.update!(
          trolley_account_status: 'active',
          tax_compliance_checked_at: Time.current
        )

        Rails.logger.info "Tax form verification successful for contractor #{contractor_id}"

        # Notify contractor of successful verification
        ContractorMailer.tax_verification_approved(contractor).deliver_now

      else
        contractor.reject_tax_form!
        Rails.logger.error "Tax form verification failed for contractor #{contractor_id}: #{tax_verification.error_message}"

        # Notify contractor of verification failure
        ContractorMailer.tax_verification_rejected(contractor, tax_verification.error_message).deliver_now
      end
    rescue StandardError => e
      contractor.reject_tax_form!
      Rails.logger.error "Exception during tax verification for contractor #{contractor_id}: #{e.message}"

      # Notify contractor of exception
      ContractorMailer.tax_verification_error(contractor, e.message).deliver_now
    end
  end

  private

  def build_recipient_data(contractor, form_data)
    user = contractor.user

    {
      referenceId: "contractor_#{contractor.id}",
      email: contractor.paypal_payout_email || user.email,
      name: "#{user.first_name} #{user.last_name}",
      firstName: user.first_name,
      lastName: user.last_name,
      type: form_data[:recipient_type] || 'individual',
      taxType: contractor.tax_form_type,
      address: {
        street1: form_data[:address_line1],
        street2: form_data[:address_line2],
        city: form_data[:city],
        region: form_data[:state],
        country: form_data[:country],
        postalCode: form_data[:postal_code]
      },
      dateOfBirth: form_data[:date_of_birth],
      ssn: form_data[:ssn], # For W-9
      taxId: form_data[:tax_id] # For W-8BEN
    }.compact
  end
end
