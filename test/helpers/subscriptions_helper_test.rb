require "test_helper"

class SubscriptionsHelperTest < ActionView::TestCase
  test "blank slate reflects whether the subscription has accounts" do
    @subscription = subscriptions(:john)
    refute blank_slate?

    @subscription = subscriptions(:john_family)
    assert blank_slate?
  end

  test "balance cell renders amount, classes, and optional tag and id" do
    bucket = buckets(:john_checking_dining)

    html = balance_cell(bucket, tag: "th", id: "dining_balance", classes: ["highlight"])
    cell = Nokogiri::HTML.fragment(html).at_css("th#dining_balance")

    assert_equal "$2.00", cell.text.strip
    assert_equal %w[number highlight current_balance], cell["class"].split
  end

  test "format amount handles negatives and digit grouping" do
    assert_equal "$1,234.56", format_amount(-123456)
    assert_equal "$0.05", format_amount(5)
  end

  private

    def subscription
      @subscription
    end
end
