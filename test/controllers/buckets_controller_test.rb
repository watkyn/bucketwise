require "test_helper"

class BucketsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  test "index should 404 when when user without permissions requests page" do
    get account_buckets_path(accounts(:tim_checking))
    assert_response :not_found
  end

  test "index should load account and subscription and render page" do
    account = accounts(:john_checking)

    get account_buckets_path(account)

    assert_response :ok
    assert_select ".navigation a[href=?]", subscription_path(subscriptions(:john))
    assert_select "h2", text: /Buckets in #{account.name}/
    assert_select "table#accounts_summary tr.bucket", count: account.buckets.count

    account.buckets.each do |bucket|
      assert_select "a.bucket[href=?]", bucket_path(bucket), text: bucket.name
    end

    assert_select "#filter_nubbin", text: "Filter"
    assert_select "a", text: "reset this filter", count: 0
  end

  test "index with filter options should set filter and return only matching buckets" do
    account = accounts(:john_checking)

    get account_buckets_path(account), params: { expenses: true }

    assert_response :ok

    # the filter is active
    assert_select "#filter_nubbin", text: "Filter: expenses"
    assert_select "a", text: "reset this filter", count: 1

    # only the buckets holding expense line items are listed
    assert_select "table#accounts_summary tr.bucket", count: 2
    assert_select "a.bucket[href=?]", bucket_path(buckets(:john_checking_aside)), text: "Aside"
    assert_select "a.bucket[href=?]", bucket_path(buckets(:john_checking_dining)), text: "Dining"
    assert_select "a.bucket[href=?]", bucket_path(buckets(:john_checking_general)), count: 0
    assert_select "a.bucket[href=?]", bucket_path(buckets(:john_checking_groceries)), count: 0
    assert_select "a.bucket[href=?]", bucket_path(buckets(:john_checking_household)), count: 0
  end

  test "show should 404 when when user without permissions requests page" do
    get bucket_path(buckets(:tim_checking_general))
    assert_response :not_found
  end

  test "show should load bucket, account, and subscription and render page" do
    bucket = buckets(:john_checking_dining)

    get bucket_path(bucket)

    assert_response :ok
    assert_select "h2#name_bucket_#{bucket.id}", text: /Dining/
    assert_select ".navigation a[href=?]", subscription_path(subscriptions(:john))
    assert_select ".navigation a[href=?]", account_path(accounts(:john_checking))
    assert_select ".navigation a[href=?]", account_buckets_path(accounts(:john_checking))
  end

  test "show should render the account name as a real link, not escaped HTML" do
    get bucket_path(buckets(:john_checking_dining))
    assert_response :ok

    assert_select "h2 a[href=?]", account_path(accounts(:john_checking)) do |links|
      assert_equal "Checking", links.first.text
    end
    refute_includes @response.body, "&lt;a href=",
      "expected a real <a> element for the account name, found escaped HTML instead"
  end

  test "update should 404 when user without permissions requests page" do
    put bucket_path(buckets(:tim_checking_general)),
      params: { bucket: { name: "Hi!" } }, as: :turbo_stream

    assert_response :not_found
    assert_equal "General", buckets(:tim_checking_general).reload.name
  end

  test "update should change bucket name and render javascript" do
    bucket = buckets(:john_checking_general)

    put bucket_path(bucket), params: { bucket: { name: "Hi!" } }, as: :turbo_stream

    assert_response :ok
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_includes @response.body, %(<turbo-stream action="replace" target="name_bucket_#{bucket.id}">)
    assert_includes @response.body, "Hi!"
    assert_equal "Hi!", bucket.reload.name
  end

  test "destroy without receiver_id should 404" do
    assert_no_difference -> { Bucket.count } do
      delete bucket_path(buckets(:john_checking_dining))
      assert_response :not_found
    end
  end

  test "destroy should assimilate line items and destroy bucket" do
    dining = buckets(:john_checking_dining)
    groceries = buckets(:john_checking_groceries)

    assert_difference -> { Bucket.count }, -1 do
      delete bucket_path(dining), params: { receiver_id: groceries.id }
    end

    assert_redirected_to bucket_path(groceries)
    assert_not Bucket.exists?(dining.id)
    assert_equal groceries, line_items(:john_lunch_checking_dining).reload.bucket
  end

  # == API tests ========================================================================

  test "index via API should return bucket list for account" do
    get account_buckets_path(accounts(:john_checking), format: :json)

    assert_response :success
    assert_equal accounts(:john_checking).buckets.length, @response.parsed_body.length
  end

  test "show via API should return bucket record" do
    get bucket_path(buckets(:john_checking_dining), format: :json)

    assert_response :success
    assert_equal buckets(:john_checking_dining).id, @response.parsed_body["id"]
  end

  test "new via API should return a template JSON response" do
    get new_account_bucket_path(accounts(:john_checking), format: :json)

    assert_response :success
    json = @response.parsed_body
    assert json
    assert_not json["id"]
  end

  test "create via API should return 422 with error messages when validations fail" do
    post account_buckets_path(accounts(:john_checking), format: :json),
      params: { bucket: { name: "Dining", role: "" } }

    assert_response :unprocessable_entity
    assert @response.parsed_body.any?
  end

  test "create via API should create record and respond with 201" do
    assert_difference -> { accounts(:john_checking).buckets.count } do
      post account_buckets_path(accounts(:john_checking), format: :json),
        params: { bucket: { name: "Utilities", role: "" } }

      assert_response :created
      assert @response.headers["Location"]
    end
  end

  test "create via API with basic auth skips forgery protection" do
    with_forgery_protection do
      assert_difference -> { accounts(:john_checking).buckets.count } do
        post account_buckets_path(accounts(:john_checking), format: :json),
          params: { bucket: { name: "No-CSRF Bucket", role: "" } },
          headers: basic_auth_headers(:john)

        assert_response :created
      end
    end
  end

  test "cookie-session JSON writes without a CSRF token are still rejected" do
    with_forgery_protection do
      assert_no_difference -> { Bucket.count } do
        post account_buckets_path(accounts(:john_checking), format: :json),
          params: { bucket: { name: "Should Not Exist", role: "" } }

        assert_response :unprocessable_entity
      end
    end
  end

  test "update via API should update record and respond with 200" do
    put bucket_path(buckets(:john_checking_dining), format: :json),
      params: { bucket: { name: "Hi!" } }

    assert_response :success
    assert_equal "Hi!", @response.parsed_body["name"]
  end

  test "update via API with validation errors should respond with 422" do
    put bucket_path(buckets(:john_checking_dining), format: :json),
      params: { bucket: { name: "Groceries" } }

    assert_response :unprocessable_entity
    assert @response.parsed_body.any?
  end

  test "destroy via API should remove record and respond with 200" do
    assert_difference -> { Bucket.count }, -1 do
      delete bucket_path(buckets(:john_checking_dining), format: :json),
        params: { receiver_id: buckets(:john_checking_groceries).id }
      assert_response :success
    end
  end
end
