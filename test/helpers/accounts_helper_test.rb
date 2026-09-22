require "test_helper"

class AccountsHelperTest < ActionView::TestCase
  test "starting balance helper formats cents and returns its date" do
    @account = accounts(:john_checking)
    occurred_on = Date.new(2025, 12, 31)
    @account.starting_balance = { amount: 12345, occurred_on: occurred_on }

    assert_equal "123.45", account_starting_balance_amount
    assert_equal occurred_on, account_starting_balance_occurred_on
  end

  test "zero starting balance has no amount and malformed date falls back to today" do
    @account = accounts(:john_checking)
    @account.starting_balance = { amount: 0, occurred_on: "not a date" }

    assert_nil account_starting_balance_amount
    assert_equal Date.current, account_starting_balance_occurred_on
  end
end
