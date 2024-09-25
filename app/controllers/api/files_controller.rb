module Api
  class FilesController < ApplicationController
    # Set up the S3 bucket before each action
    before_action :set_s3_bucket
    #! Remove this line once login is implemented
    skip_before_action :verify_authenticity_token

    # GET /api/files
    # List all files in the S3 bucket and return their public URLs.
    def index
      # Collect all object URLs from the bucket
      @files = @bucket.objects.collect(&:public_url)
      render json: @files
    end

    # POST /api/files
    # Upload a new file to the S3 bucket.
    # Requires a file to be present in the request parameters.
    def create
      if params[:file].present?
        # Retrieve the uploaded file
        file = params[:file]

        # Create a new object in the S3 bucket with the file's original name
        obj = @bucket.object(file.original_filename)

        # Upload the file to S3 with public-read access (adjust as needed)
        obj.upload_file(file.tempfile, acl: 'public-read')

        # Return the URL of the uploaded file
        render json: { success: true, url: obj.public_url.to_s }, status: :created
      else
        # Handle cases where no file was uploaded
        render json: { success: false, message: "No file uploaded" }, status: :unprocessable_entity
      end
    end

    # DELETE /api/files/:id
    # Delete a file from the S3 bucket.
    # The `id` parameter is used as the file name to identify the file to delete.
    def destroy
      file_key = params[:id] # Assuming `id` is the file name
      obj = @bucket.object(file_key)

      # Attempt to delete the file from the bucket
      if obj.delete
        render json: { success: true, message: "File deleted successfully" }
      else
        # Handle cases where the file could not be deleted
        render json: { success: false, message: "Failed to delete file" }, status: :unprocessable_entity
      end
    end

    private

    # Set the S3 bucket instance variable
    # This method initializes the S3 bucket for use in the controller actions
    def set_s3_bucket
      @bucket = S3_BUCKET
    end
  end
end
