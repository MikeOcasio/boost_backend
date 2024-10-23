  # == Schema Information
  #
  # Table name: orders
  #
  #  id         :bigint           not null, primary key
  #  user_id    :bigint           not null
  #  product_id :bigint           not null
  #  status     :string
  #  total_price: decimal
  #  created_at :datetime         not null
  #  updated_at :datetime         not null'
  #  internal_id: string
  #
  # Relationships
  # - belongs_to :user
  # - belongs_to :product

class Order < ApplicationRecord
  include AASM

  scope :graveyard_orders, -> { where(assigned_skill_master_id: nil) }

  belongs_to :user
  belongs_to :platform_credential
  has_many :order_products, dependent: :destroy
  has_many :products, through: :order_products
  has_one :promotion, through: :products

  attr_accessor :selected_level, :dynamic_price

  before_create :generate_internal_id
  after_touch :update_totals
  before_save :assign_platform_credentials

  validates :state, presence: true
  validates :internal_id, uniqueness: true
  validates :user, presence: true

  aasm column: 'state' do
    state :open, initial: true
    state :assigned
    state :in_progress
    state :delayed
    state :disputed
    state :re_assigned
    state :complete

    # Define state transitions
    event :assign do
      # Transition from `open` to `assigned` only if `assigned_skill_master_id` is set
      transitions from:  [:re_assigned, :open], to: :assigned, guard: :skill_master_assigned?
    end

    event :start_progress do
      transitions from: :assigned, to: :in_progress #! Need to add reassign logic
    end

    event :mark_delayed do
      transitions from: :in_progress, to: :delayed
    end

    event :mark_disputed do
      transitions from: [:assigned, :in_progress, :delayed], to: :disputed
    end

    event :re_assign do
      transitions from: [:assigned, :in_progress, :disputed, :delayed], to: :re_assigned
    end

    event :complete_order do
      transitions from: [:in_progress, :delayed], to: :complete
    end
  end

  def generate_internal_id
    self.internal_id = SecureRandom.hex(5) # generates a random 20-character string
  end

  def calculate_price
    self.price = order_products.includes(:product).sum { |order_product| order_product.product.price }
  end

  def calculate_tax
    self.tax = order_products.includes(:product).sum { |order_product| order_product.product.tax }
  end

  def calculate_total_price
    self.total_price = price + tax
  end

  def update_totals
    calculate_price
    calculate_tax
    calculate_total_price
    save
  end

  def assign_platform_credentials
    if platform_credential.nil? && user.present? && platform.present?
      self.platform_credential = user.platform_credentials.find_by(platform_id: platform)
    end
  end

  def skill_master_assigned?
    assigned_skill_master_id.present?
  end

end
