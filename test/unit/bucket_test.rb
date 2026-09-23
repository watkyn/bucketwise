require 'test_helper'

class BucketTest < ActiveSupport::TestCase
  test "assimilate should change all references of argument to self and destroy argument" do
    groceries = buckets(:john_checking_groceries)
    dining = buckets(:john_checking_dining)
    old_groceries_balance = groceries.balance
    old_dining_balance = dining.balance

    groceries.assimilate(dining)

    assert !Bucket.exists?(dining.id)
    assert_equal groceries, line_items(:john_lunch_checking_dining).reload.bucket
    assert_equal groceries.reload.balance, old_groceries_balance + old_dining_balance
  end

  test "assimilate combines matching line items from the same event" do
    dining = buckets(:john_checking_dining)
    groceries = buckets(:john_checking_groceries)
    event = events(:john_lunch_again)
    original_amount = line_items(:john_lunch_again_checking_dining).amount
    donor_amount = -50

    LineItem.create!(
      event: event,
      account: groceries.account,
      bucket: groceries,
      amount: donor_amount,
      role: "credit_options",
      occurred_on: event.occurred_on
    )

    dining.assimilate(groceries)

    matching_items = event.line_items.where(bucket: dining, role: "credit_options")
    assert_equal 1, matching_items.count
    assert_equal original_amount + donor_amount, matching_items.sole.amount
  end

  test "assimilate nets line items that collapse onto one bucket and drops emptied events" do
    general = buckets(:john_checking_general)
    dining = buckets(:john_checking_dining)
    reallocate_from = events(:john_reallocate_from)
    reallocate_to = events(:john_reallocate_to)
    old_balance = general.balance + dining.balance

    general.assimilate(dining)

    assert_not Bucket.exists?(dining.id)
    assert_equal old_balance, general.reload.balance

    # Both reallocation events moved a leg onto General, where each event
    # already had a leg: each pair nets to zero, so the events are no-ops.
    assert_not Event.exists?(reallocate_from.id)
    assert_not Event.exists?(reallocate_to.id)
    assert_empty LineItem.where(event_id: [reallocate_from.id, reallocate_to.id])

    # No event may keep two legs on the same bucket of one account.
    duplicates = LineItem.group(:event_id, :account_id, :bucket_id)
      .having("COUNT(*) > 1").count
    assert_empty duplicates
  end

  test "assimilate bucket from different account should raise exception and make no change" do
    groceries = buckets(:john_checking_groceries)
    general = buckets(:john_mastercard_general)

    assert_raises ArgumentError do
      groceries.assimilate(general)
    end

    assert Bucket.exists?(general.id)
    assert_equal general, line_items(:john_lunch_mastercard).reload.bucket
  end

  test "assimilate self should raise exception and make no change" do
    groceries = buckets(:john_checking_groceries)

    assert_no_difference "Bucket.count" do
      assert_raises ArgumentError do
        groceries.assimilate(groceries)
      end
    end
  end

  test "blank names should be disallowed" do
    assert_no_difference "Bucket.count" do
      bucket = accounts(:john_checking).buckets.create(name: "", role: "", author: users(:john))
      assert bucket.errors[:name].any?
    end
  end

  test "duplicate names are allowed for different accounts" do
    assert_difference "Bucket.count" do
      bucket = accounts(:john_savings).buckets.create(name: buckets(:john_checking_dining).name, role: "", author: users(:john))
      assert bucket.valid?
    end
  end

  test "duplicate names are disallowed within the same account" do
    assert_no_difference "Bucket.count" do
      bucket = accounts(:john_checking).buckets.create(name: buckets(:john_checking_dining).name, role: "", author: users(:john))
      assert bucket.errors[:name].any?
    end
  end

  test "balance should read computed_balance if that value is set" do
    filter = QueryFilter.new(expenses: true)
    dining = accounts(:john_checking).buckets.filtered(filter).find_by(name: "Dining")
    assert dining[:computed_balance]
    assert_not_equal dining[:balance], dining[:computed_balance]
    assert_equal dining[:computed_balance].to_i, dining.balance
  end
end
