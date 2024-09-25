# app/services/s3_service.rb
class S3Service
  def upload(file, key)
    obj = S3_BUCKET.object(key)
    obj.upload_file(file.path, acl: 'public-read')
    obj.public_url
  end
end
