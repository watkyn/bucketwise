require "test_helper"

class PageableTest < ActiveSupport::TestCase
  test "page returns the requested ordered slice and whether another page exists" do
    items = accounts(:john_checking).account_items

    more_pages, first_page = items.page(0, size: 2)
    another_page, second_page = items.page(1, size: 2)

    assert more_pages
    assert_equal 2, first_page.length
    assert_equal 2, second_page.length
    assert_empty first_page.map(&:id) & second_page.map(&:id)
    assert_operator first_page.first.occurred_on, :>=, first_page.last.occurred_on
    assert another_page
  end

  test "last page reports that no further page exists" do
    more_pages, records = accounts(:john_checking).account_items.page(99, size: 2)

    assert_not more_pages
    assert_empty records
  end
end
