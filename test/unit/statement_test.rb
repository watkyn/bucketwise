require 'test_helper'

class StatementTest < ActiveSupport::TestCase
  test "creation with ending balance as dollars should be translated to cents" do
    statement = accounts(:john_checking).statements.create(occurred_on: Date.current, ending_balance: "1,234.56")
    assert_equal 123456, statement.ending_balance
  end

  test "creation with cleared ids should set statement id for given account items" do
    items = [:john_checking_starting_balance, :john_bill_pay_checking].map { |i| account_items(i).id }

    statement = accounts(:john_checking).statements.create(
      occurred_on: Date.current, ending_balance: 123456, cleared: items)

    assert_equal items.sort, statement.account_items.map(&:id).sort
  end

  test "creation with cleared ids should filter out items for different accounts" do
    items = [:john_checking_starting_balance, :john_bill_pay_checking].map { |i| account_items(i).id }
    bad_items = items + [account_items(:john_lunch_mastercard).id]

    statement = accounts(:john_checking).statements.create(
      occurred_on: Date.current, ending_balance: 123456, cleared: bad_items)

    assert_equal items.sort, statement.account_items.map(&:id).sort
  end

  test "balanced_at should not be set when no items have been given" do
    statement = accounts(:john_checking).statements.create(occurred_on: Date.current, ending_balance: 123456)
    assert_nil statement.balanced_at
  end

  test "balanced_at should be set automatically when items all balance" do
    statements(:john).destroy

    items = [:john_checking_starting_balance, :john_bill_pay_checking].map { |i| account_items(i).id }

    statement = accounts(:john_checking).statements.create(
      occurred_on: Date.current, ending_balance: 99225, cleared: items)

    assert_not_nil statement.balanced_at
    assert (Time.current - statement.balanced_at) < 1
  end

  test "balanced_at should be cleared automatically when items do not balance" do
    items = [:john_checking_starting_balance, :john_bill_pay_checking].map { |i| account_items(i).id }

    statement = accounts(:john_checking).statements.create(occurred_on: Date.current, ending_balance: 123456)
    statement.update_column(:balanced_at, Time.current)

    assert_not_nil statement.reload.balanced_at

    statement.update(cleared: items)
    assert_nil statement.reload.balanced_at
  end

  test "deleting statement should nullify association with account items" do
    assert statements(:john).account_items.any?
    assert_equal statements(:john), account_items(:john_checking_starting_balance).statement

    assert_difference "Statement.count", -1 do
      assert_no_difference "AccountItem.count" do
        statements(:john).destroy
      end
    end

    assert_nil account_items(:john_checking_starting_balance).reload.statement
  end

  test "balanced should be true when unsettled balance is zero" do
    assert statements(:john).balanced?
    statements(:john).update(ending_balance: 123456, cleared: statements(:john).account_items.map(&:id))
    assert_not statements(:john).reload.balanced?
  end

  test "ending_balance should not have truncation errors" do
    statements(:john).update_column(:ending_balance, (2557.68 * 100).round)
    assert_equal 255768, statements(:john).reload.ending_balance
    # also test via setter with float
    s = accounts(:john_checking).statements.build(occurred_on: Date.current, ending_balance: 2557.68)
    s.save
    assert_equal 255768, s.ending_balance
  end
end
