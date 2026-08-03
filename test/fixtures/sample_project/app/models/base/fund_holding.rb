class Base::FundHolding < ApplicationRecord
  belongs_to :fund
  has_many :transactions
end
