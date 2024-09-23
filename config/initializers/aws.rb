require 'aws-sdk-s3'

Aws.config.update({
  region: Rails.application.credentials.dig(:amazon, :region),
  credentials: Aws::Credentials.new(
    Rails.application.credentials.dig(:aws, :access_key_id),
    Rails.application.credentials.dig(:aws, :secret_access_key)
  )
})

# Define a constant for the S3 bucket
S3_BUCKET = Aws::S3::Resource.new.bucket(Rails.application.credentials.dig(:amazon, :bucket))
