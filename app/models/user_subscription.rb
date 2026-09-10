class UserSubscription < ApplicationRecord
  belongs_to :subscription
  belongs_to :user
end
