require 'test_helper'

class QueryFilterTest < ActiveSupport::TestCase
  test "reads string-keyed options as passed from controller params" do
    filter = QueryFilter.new("from" => "2020-01-01", "to" => "2020-01-31",
      "expenses" => "1", "deposits" => nil, "reallocations" => nil)

    assert filter.from?
    assert_equal Date.new(2020, 1, 1), filter.from
    assert filter.to?
    assert_equal Date.new(2020, 1, 31), filter.to
    assert filter.by_type?
    assert filter.expenses?
    assert !filter.deposits?
    assert !filter.reallocations?
    assert filter.any?
  end

  test "reads symbol-keyed options" do
    filter = QueryFilter.new(from: "2020-06-15")

    assert filter.from?
    assert_equal Date.new(2020, 6, 15), filter.from
  end

  test "defaults when options are empty" do
    filter = QueryFilter.new

    assert !filter.from?
    assert !filter.to?
    assert !filter.any?
    assert filter.expenses? && filter.deposits? && filter.reallocations?
  end
end
