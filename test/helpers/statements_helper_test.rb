require "test_helper"

class StatementsHelperTest < ActionView::TestCase
  test "uncleared rows alternate and cleared rows include their marker" do
    uncleared = account_items(:john_lunch_checking)
    cleared = account_items(:john_checking_starting_balance)

    assert_equal "odd", uncleared_row_class(uncleared)
    assert_equal "even cleared", uncleared_row_class(cleared)
  end
end
