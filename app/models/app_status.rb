class AppStatus < ApplicationRecord
  validates :status, presence: true, inclusion: { in: ['active', 'maintenance'] }
  validates :message, presence: true

  def self.current
    first_or_create!(status: 'active', message: 'Application is running normally')
  end

  def maintenance?
    status == 'maintenance'
  end
end
