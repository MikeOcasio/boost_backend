module ImageHelper
  def test_image_path
    Rails.root.join('spec/fixtures/test_image.jpg')
  end

  def create_test_image
    FileUtils.mkdir_p(File.dirname(test_image_path))
    return if File.exist?(test_image_path)

    # Create a small test image if it doesn't exist
    system "convert -size 100x100 xc:white #{test_image_path}"
  end

  def base64_image
    create_test_image
    "data:image/jpeg;base64,#{Base64.strict_encode64(File.read(test_image_path))}"
  end
end
