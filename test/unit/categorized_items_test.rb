require "test_helper"

class CategorizedItemsTest < ActiveSupport::TestCase
  test "account items are categorized by amount and event check number" do
    deposits = accounts(:john_checking).account_items.deposits
    checks = accounts(:john_checking).account_items.checks
    expenses = accounts(:john_mastercard).account_items.expenses

    assert_includes deposits, account_items(:john_checking_starting_balance)
    assert_equal [account_items(:john_bill_pay_checking)], checks
    assert_includes expenses, account_items(:john_lunch_mastercard)
    assert_includes expenses, account_items(:john_bare_mastercard)
    assert expenses.all? { |item| item.amount.negative? && item.event.check_number.blank? }
  end
end
