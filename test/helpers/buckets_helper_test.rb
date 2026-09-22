require "test_helper"

class BucketsHelperTest < ActionView::TestCase
  test "source view defaults to index and accepts the requested view" do
    assert_equal "index", source_view

    params[:view] = "expenses"
    assert_equal "expenses", source_view
  end

  test "possible receiver buckets exclude the current bucket and sort by name" do
    @account = accounts(:john_checking)
    @bucket = buckets(:john_checking_dining)

    assert_equal ["Aside", "General", "Groceries", "Household"],
      possible_receiver_buckets.map(&:name)
    refute_includes possible_receiver_buckets, @bucket
  end

  private

    def account
      @account
    end

    def bucket
      @bucket
    end
end
