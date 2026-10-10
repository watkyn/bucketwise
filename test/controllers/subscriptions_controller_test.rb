require "test_helper"

class SubscriptionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  test "index should redirect to sole subscription if there is only one" do
    sign_in :tim

    get subscriptions_path
    assert_redirected_to subscription_path(subscriptions(:tim))
  end

  test "index should list all subscriptions if there are many" do
    get subscriptions_path

    assert_response :ok
    assert_select "h2", text: /Your Subscriptions/
    assert_select "ul li", 2
    assert_select "li#subscription_#{subscriptions(:john).id}"
    assert_select "li#subscription_#{subscriptions(:john_family).id}"
  end

  test "index should not include any subscriptions not accessible to user" do
    get subscriptions_path

    assert_response :ok
    assert_select "li#subscription_#{subscriptions(:john).id}"
    assert_select "li#subscription_#{subscriptions(:john_family).id}"
    assert_select "li#subscription_#{subscriptions(:tim).id}", 0
  end

  test "show should 404 for invalid subscription" do
    assert_not Subscription.exists?(1)

    get subscription_path(1)
    assert_response :not_found
  end

  test "show should 404 for inaccessible subscription" do
    get subscription_path(subscriptions(:tim))
    assert_response :not_found
  end

  test "show should display dashboard for selected subscription" do
    get subscription_path(subscriptions(:john))

    assert_response :ok
    assert_select "#subscription[data-events-form-return-to-value=?]",
      subscription_path(subscriptions(:john))
    assert_select "#accounts_summary a[href=?]", account_path(accounts(:john_checking)),
      text: "Checking"
  end

  test "dashboard inline form offers a description above tags for reallocations" do
    get subscription_path(subscriptions(:john))

    assert_response :ok
    assert_select "#new_event #reallocate_from"
    assert_select "#new_event #reallocate_to"
    assert_select "#new_event #memo_link a", text: /I'd like to add a description for this transaction/
    assert_select "#new_event #memo.hidden textarea[name='event[memo]']"
    assert_operator @response.body.index('id="memo_link"'), :<, @response.body.index('id="tags_collapsed"')
  end

  test "show leaves bucket-row plus-minus buttons without a navigate URL for the inline form" do
    get subscription_path(subscriptions(:john))

    assert_response :ok
    bucket = buckets(:john_checking_dining)
    assert_select "tr#bucket_#{bucket.id}[data-buckets-new-event-url-value='']", 1
  end

  test "layout should expose a plain events-source location without extra JSON quotes" do
    get subscription_path(subscriptions(:john))

    assert_response :ok
    assert_includes @response.body,
      'data-events-source-location-value="subscriptions"',
      "the String location value must not be wrapped in extra double quotes"
    refute_includes @response.body, 'data-events-source-location-value="&quot;'
  end

  # == API tests ========================================================================

  test "index via API should return list of all subscriptions available to user" do
    get subscriptions_path(format: :json)

    assert_response :ok
    json = @response.parsed_body
    assert json.is_a?(Array)
    assert json.any?
    assert_equal users(:john).subscriptions.pluck(:id).sort, json.map { |subscription| subscription["id"] }.sort
  end

  test "show via API should return 404 for inaccessible subscription" do
    get subscription_path(subscriptions(:tim), format: :json)
    assert_response :not_found
  end

  test "show should return requested subscription record" do
    get subscription_path(subscriptions(:john), format: :json)

    assert_response :ok
    json = @response.parsed_body
    assert_equal subscriptions(:john).id, json["id"]
  end
end
