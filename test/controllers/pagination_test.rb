require "test_helper"

class PaginationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  test "account show uses the requested page of account items" do
    account = accounts(:john_checking)

    get account_path(account)
    assert_response :ok
    assert_select "table.entries tr[id^='event_']", minimum: 1

    get account_path(account), params: { page: 1 }
    assert_response :ok
    assert_select "table.entries tr[id^='event_']", count: 0
  end

  test "bucket show uses the requested page of line items" do
    bucket = buckets(:john_checking_dining)

    get bucket_path(bucket)
    assert_response :ok
    assert_select "table.entries tr[id^='event_']", minimum: 1

    get bucket_path(bucket), params: { page: 1 }
    assert_response :ok
    assert_select "table.entries tr[id^='event_']", count: 0
  end

  test "tag show uses the requested page of tagged items" do
    tag = tags(:john_lunch)

    get tag_path(tag)
    assert_response :ok
    assert_select "table.entries tr[id^='event_']", minimum: 1

    get tag_path(tag), params: { page: 1 }
    assert_response :ok
    assert_select "table.entries tr[id^='event_']", count: 0
  end
end
