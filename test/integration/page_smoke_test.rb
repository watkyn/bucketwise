require "test_helper"

# Promotes the ad-hoc route probe into a permanent regression test:
# every page with an HTML view must render for a logged-in user, and
# the JSON index/show endpoints must stay green.
class PageSmokeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:john)
    @subscription = subscriptions(:john)
    @account = accounts(:john_checking)
    @bucket = buckets(:john_checking_general)
    @tag = tags(:john_tip)
    @statement = statements(:john)
    @event = Event.first
  end

  test "health and login pages respond without a session" do
    get "/up"
    assert_response :success

    get "/session/new"
    assert_response :success
  end

  test "login lands on the subscription dashboard" do
    post "/session", params: { user_name: @user.user_name, password: "testing" }
    assert_response :redirect

    follow_redirect!
    assert_response :success
    assert_match %r{/subscriptions}, @response.request.path
  end

  test "core HTML pages render" do
    post "/session", params: { user_name: @user.user_name, password: "testing" }

    paths = [
      "/",
      "/subscriptions/#{@subscription.id}",
      "/subscriptions/#{@subscription.id}/accounts/new",
      "/subscriptions/#{@subscription.id}/events/new",
      "/accounts/#{@account.id}",
      "/accounts/#{@account.id}/buckets",
      "/accounts/#{@account.id}/statements",
      "/buckets/#{@bucket.id}",
      "/events/#{@event.id}/edit",
      "/tags/#{@tag.id}",
      "/statements/#{@statement.id}",
      "/statements/#{@statement.id}/edit",
      "/change_password"
    ]

    paths.each do |path|
      get path
      assert_response :success, "expected 200 for #{path}, got #{@response.status}"
    end
  end

  test "JSON index and show endpoints respond" do
    post "/session", params: { user_name: @user.user_name, password: "testing" }

    paths = [
      "/subscriptions.json",
      "/subscriptions/#{@subscription.id}.json",
      "/subscriptions/#{@subscription.id}/accounts.json",
      "/subscriptions/#{@subscription.id}/events.json",
      "/subscriptions/#{@subscription.id}/tags.json",
      "/accounts/#{@account.id}.json",
      "/accounts/#{@account.id}/events.json",
      "/buckets/#{@bucket.id}.json",
      "/buckets/#{@bucket.id}/events.json",
      "/tags/#{@tag.id}.json",
      "/events/#{@event.id}.json"
    ]

    paths.each do |path|
      get path
      assert_response :success, "expected 200 for #{path}, got #{@response.status}"
      JSON.parse(@response.body)
    end
  end

  test "bare events index redirects instead of raising" do
    post "/session", params: { user_name: @user.user_name, password: "testing" }

    get "/events"
    assert_response :redirect
  end
end
