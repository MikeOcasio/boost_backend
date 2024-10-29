class PlatformCredential < ApplicationRecord
  belongs_to :user
  has_many :orders
  belongs_to :platform
  belongs_to :sub_platform, optional: true

  encrypts :username
  encrypts :password

  validates :username, :password, presence: true
  validate :check_sub_platform_restrictions

  private

  def check_sub_platform_restrictions
    if sub_platform.nil? && platform.has_sub_platforms
      errors.add(:base, 'Platform has sub-platforms; use sub-platform credentials')
    elsif sub_platform.present? && !platform.has_sub_platforms
      errors.add(:base, 'This platform does not allow sub-platforms')
    end
  end
end
