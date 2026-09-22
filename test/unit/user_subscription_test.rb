require "test_helper"

class UserSubscriptionTest < ActiveSupport::TestCase
  test "membership joins its user and subscription" do
    membership = user_subscriptions(:john)

    assert_equal users(:john), membership.user
    assert_equal subscriptions(:john), membership.subscription
    assert_includes users(:john).subscriptions, subscriptions(:john)
  end

  test "membership requires a user and subscription" do
    membership = UserSubscription.new

    assert_not membership.valid?
    assert membership.errors[:user].any?
    assert membership.errors[:subscription].any?
  end
end
