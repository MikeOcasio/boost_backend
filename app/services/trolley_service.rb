class TrolleyService
  def initialize
    @api_key = Rails.application.credentials.trolley&.dig(:api_key) || ENV['TROLLEY_API_KEY']
    @api_secret = Rails.application.credentials.trolley&.dig(:api_secret) || ENV['TROLLEY_API_SECRET']
    @base_url = Rails.env.production? ? 'https://api.trolley.com' : 'https://api.sandbox.trolley.com'

    validate_credentials!
  end

  def create_recipient(recipient_data)
    response = make_request('POST', '/recipients', recipient_data)

    if response['ok']
      OpenStruct.new(
        id: response['recipient']['id'],
        status: response['recipient']['status'],
        successful?: true
      )
    else
      OpenStruct.new(
        successful?: false,
        error_message: response['message'] || 'Unknown error creating recipient'
      )
    end
  end

  def update_recipient(recipient_id, recipient_data)
    response = make_request('PATCH', "/recipients/#{recipient_id}", recipient_data)

    if response['ok']
      OpenStruct.new(
        id: response['recipient']['id'],
        status: response['recipient']['status'],
        successful?: true
      )
    else
      OpenStruct.new(
        successful?: false,
        error_message: response['message'] || 'Unknown error updating recipient'
      )
    end
  end

  def submit_tax_form(recipient_id, form_type, form_data)
    tax_form_data = build_tax_form_data(form_type, form_data)
    response = make_request('POST', "/recipients/#{recipient_id}/tax-forms", tax_form_data)

    if response['ok']
      OpenStruct.new(
        form_id: response['taxForm']['id'],
        status: response['taxForm']['status'],
        successful?: true
      )
    else
      OpenStruct.new(
        successful?: false,
        error_message: response['message'] || 'Tax form submission failed'
      )
    end
  end

  def get_recipient_status(recipient_id)
    response = make_request('GET', "/recipients/#{recipient_id}")

    if response['ok']
      recipient = response['recipient']
      OpenStruct.new(
        id: recipient['id'],
        status: recipient['status'],
        compliance_status: recipient['complianceStatus'],
        tax_form_status: recipient['taxFormStatus'],
        successful?: true
      )
    else
      OpenStruct.new(
        successful?: false,
        error_message: response['message'] || 'Failed to get recipient status'
      )
    end
  end

  private

  def validate_credentials!
    unless @api_key && @api_secret
      if Rails.env.production?
        raise "Trolley credentials not configured"
      else
        Rails.logger.warn "Trolley credentials not configured - using environment variables if available"
      end
    end
  end

  def make_request(method, endpoint, data = nil)
    uri = URI("#{@base_url}#{endpoint}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    case method.upcase
    when 'GET'
      request = Net::HTTP::Get.new(uri)
    when 'POST'
      request = Net::HTTP::Post.new(uri)
      request.body = data.to_json if data
    when 'PATCH'
      request = Net::HTTP::Patch.new(uri)
      request.body = data.to_json if data
    end

    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    request['X-API-Secret'] = @api_secret

    begin
      response = http.request(request)
      JSON.parse(response.body)
    rescue StandardError => e
      Rails.logger.error "Trolley API request failed: #{e.message}"
      { 'ok' => false, 'message' => e.message }
    end
  end

  def build_tax_form_data(form_type, form_data)
    case form_type
    when 'W-9'
      {
        taxForm: {
          formType: 'W-9',
          businessName: form_data[:business_name],
          taxClassification: form_data[:tax_classification],
          ssn: form_data[:ssn],
          ein: form_data[:ein],
          address: {
            street1: form_data[:address_line1],
            street2: form_data[:address_line2],
            city: form_data[:city],
            region: form_data[:state],
            country: 'US',
            postalCode: form_data[:postal_code]
          },
          signedAt: Time.current.iso8601
        }
      }
    when 'W-8BEN'
      {
        taxForm: {
          formType: 'W-8BEN',
          foreignTaxId: form_data[:tax_id],
          countryOfTaxResidence: form_data[:country_of_tax_residence],
          treatyBenefits: form_data[:treaty_benefits] || false,
          address: {
            street1: form_data[:address_line1],
            street2: form_data[:address_line2],
            city: form_data[:city],
            region: form_data[:state],
            country: form_data[:country],
            postalCode: form_data[:postal_code]
          },
          signedAt: Time.current.iso8601
        }
      }
    else
      raise ArgumentError, "Unsupported tax form type: #{form_type}"
    end
  end
end
