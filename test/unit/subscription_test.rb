require "test_helper"

class SubscriptionTest < ActiveSupport::TestCase
  test "recent events are paged newest first and can be filtered by actor" do
    subscription = subscriptions(:john)

    more_pages, first_page = subscription.events.recent(0, size: 2)
    _, second_page = subscription.events.recent(1, size: 2)

    assert more_pages
    assert_equal 2, first_page.length
    assert_equal 2, second_page.length
    assert_empty first_page.map(&:id) & second_page.map(&:id)
    assert_operator first_page.first.created_at, :>=, first_page.last.created_at

    _, actor_events = subscription.events.recent(0, size: 10, actor: " sandwich central ")
    assert_equal [events(:john_lunch_again).id, events(:john_lunch).id], actor_events.map(&:id)
  end

  test "prepare builds reallocation from the selected bucket" do
    bucket = buckets(:john_checking_dining)

    event = subscriptions(:john).events.prepare(role: "reallocation", from: bucket.id)

    assert_equal :reallocation, event.role
    assert_equal "Bucket reallocation", event.actor_name
    assert_equal bucket, event.line_items.to_a.find { |item| item.role == "primary" }.bucket
    assert_equal buckets(:john_checking_general),
      event.line_items.to_a.find { |item| item.role == "reallocate_from" }.bucket
  end

  test "prepare builds reallocation to the selected bucket" do
    bucket = buckets(:john_checking_dining)

    event = subscriptions(:john).events.prepare(role: "reallocation", to: bucket.id)

    assert_equal :reallocation, event.role
    assert_equal bucket, event.line_items.to_a.find { |item| item.role == "primary" }.bucket
    assert_equal buckets(:john_checking_general),
      event.line_items.to_a.find { |item| item.role == "reallocate_to" }.bucket
  end

  test "clean removes a subscription's data but preserves its membership" do
    subscription = subscriptions(:john)
    account_ids = subscription.accounts.pluck(:id)

    subscription.clean

    assert Subscription.exists?(subscription.id)
    assert_equal [users(:john).id], subscription.users.pluck(:id)
    assert_empty subscription.accounts
    assert_empty subscription.events
    assert_empty subscription.tags
    assert_empty subscription.actors
    assert_empty Statement.where(account_id: account_ids)
  end

  test "destroy removes the subscription and its membership records" do
    subscription = subscriptions(:john_family)

    subscription.destroy

    assert_not Subscription.exists?(subscription.id)
    assert_not UserSubscription.exists?(subscription_id: subscription.id)
  end
end
