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
  has_many :order_products, dependent: :destroy
  has_many :products, through: :order_products
  has_one :promotion, through: :product
  has_one :platform_credential

  before_create :generate_internal_id
  after_touch :update_totals

  aasm column: 'status' do
    state :open, initial: true
    state :pending
    state :graveyard
    state :assigned
    state :in_progress
    state :delayed
    state :disputed
    state :re_assigned
    state :complete

    # Define state transitions
    event :assign do
      transitions from: :open, to: :assigned
    end

    event :start_progress do
      transitions from: :assigned, to: :in_progress
    end

    event :mark_delayed do
      transitions from: :in_progress, to: :delayed
    end

    event :mark_disputed do
      transitions from: [:assigned, :in_progress], to: :disputed
    end

    event :re_assign do
      transitions from: [:assigned, :in_progress], to: :re_assigned
    end

    event :complete_order do
      transitions from: [:assigned, :in_progress, :delayed], to: :complete
    end
  end

  def generate_internal_id
    self.internal_id = SecureRandom.hex(5) # generates a random 20-character string
  end

  def calculate_price
    self.price = products.sum(:price)
  end

  def calculate_tax
    self.tax = products.sum(:tax)
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

end
