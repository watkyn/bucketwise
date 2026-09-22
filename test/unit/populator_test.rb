require "test_helper"

class PopulatorTest < ActiveSupport::TestCase
  test "post builder creates a deposit, account, bucket, and tag" do
    subscription = subscriptions(:john)
    occurred_on = Date.new(2026, 1, 15)

    assert_difference -> { subscription.accounts.count }, 1 do
      assert_difference -> { subscription.events.count }, 2 do
        Populator.for(subscription) do |populator|
          populator.account("Seeded Checking", "checking", 5000, occurred_on)
          populator.post(occurred_on, "Payroll", 1250).deposit("Checking", "General").tag("income")
        end
      end
    end

    account = subscription.accounts.find_by!(name: "Seeded Checking")
    assert_equal 5000, account.balance

    event = subscription.events.find_by!(actor_name: "Payroll")
    assert_equal occurred_on, event.occurred_on
    assert_equal "deposit", event.line_items.sole.role
    assert_equal 1250, event.line_items.sole.amount
    assert_equal "General", event.line_items.sole.bucket.name
    assert_equal "income", event.tagged_items.sole.name
  end

  test "post builder creates balanced expenses with full and partial tags" do
    post = Populator::Post.new(Date.current, "Market", 500)
      .check("123")
      .memo("weekly groceries")
      .source("Checking", [["Groceries", 300], ["Dining", 200]])
      .repay("Mastercard", "General")
      .tag("food", "dining" => 125)

    assert_equal "123", post.check_number
    assert_equal "weekly groceries", post.memo
    assert_equal 4, post.line_items.length
    assert_equal [-300, -200], post.line_items.first(2).map { |item| item[:amount] }
    assert_equal ["payment_source", "payment_source", "credit_options", "aside"],
      post.line_items.map { |item| item[:role] }
    assert_equal [{ tag_id: "n:food", amount: 500 }, { tag_id: "n:dining", amount: 125 }], post.tagged_items
  end

  test "transfer and reallocation builders assign opposite signed legs" do
    transfer = Populator::Post.new(Date.current, "Transfer", 400)
      .from("Checking", "General")
      .to("Savings", "General")

    assert_equal ["transfer_from", "transfer_to"], transfer.line_items.map { |item| item[:role] }
    assert_equal [-400, 400], transfer.line_items.map { |item| item[:amount] }

    reallocation = Populator::Post.new(Date.current, "Reallocation", 400)
      .reallocate("Checking", :from, "General", [["Groceries", 150], ["Dining", 250]])

    assert_equal ["reallocate_from", "reallocate_from", "primary"],
      reallocation.line_items.map { |item| item[:role] }
    assert_equal [150, 250, -400], reallocation.line_items.map { |item| item[:amount] }
  end

  test "copy duplicates a post's mutable transaction data" do
    original = Populator::Post.new(Date.current, "Market", 500)
      .memo("memo")
      .source("Checking", "Groceries")
      .tag("food")
    copy = Populator::Post.new(Date.current, "Another Market", nil).copy(original)

    assert_equal "memo", copy.memo
    assert_equal 500, copy.default_amount
    assert_equal original.line_items, copy.line_items
    assert_equal original.tagged_items, copy.tagged_items
    refute_same original.line_items, copy.line_items
    refute_same original.tagged_items, copy.tagged_items
  end
end
