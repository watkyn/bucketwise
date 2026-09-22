require "test_helper"

class ActorTest < ActiveSupport::TestCase
  test "normalize_name trims and uppercases a name" do
    assert_equal "SANDWICH CENTRAL", Actor.normalize_name("  Sandwich Central ")
  end

  test "normalize_for reuses an actor within the subscription and refreshes it" do
    actor = actors(:john_sandwich_central)
    old_time = 1.day.ago
    actor.update_column(:updated_at, old_time)

    normalized = Actor.normalize_for(subscriptions(:john), " Sandwich Central ")

    assert_equal actor, normalized
    assert_equal "Sandwich Central", normalized.name
    assert_operator normalized.reload.updated_at, :>, old_time
  end

  test "normalize_for creates separately scoped actors with a trimmed display name" do
    first = Actor.normalize_for(subscriptions(:john), " New Payee ")
    second = Actor.normalize_for(subscriptions(:tim), "New Payee")

    assert first.persisted?
    assert_equal "New Payee", first.name
    assert_equal "NEW PAYEE", first.sort_name
    assert second.persisted?
    assert_not_equal first.id, second.id
    assert_equal subscriptions(:john), first.subscription
    assert_equal subscriptions(:tim), second.subscription
  end

  test "name and sort name are required" do
    actor = Actor.new(subscription: subscriptions(:john), name: "", sort_name: "")

    assert_not actor.valid?
    assert actor.errors[:name].any?
    assert actor.errors[:sort_name].any?
  end
end
