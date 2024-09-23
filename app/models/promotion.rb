  # == Schema Information
  #
  # Table name: promotions
  #
  #  id                 :bigint           not null, primary key
  #  code               :string
  #  discount_percentage: decimal
  #  start_date         :datetime
  #  end_date           :datetime
  #  created_at         :datetime         not null
  #  updated_at         :datetime         not null


class Promotion < ApplicationRecord
end
