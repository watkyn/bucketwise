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

  test "event form connects actor and tag fields to autocomplete" do
    post "/session", params: { user_name: @user.user_name, password: "testing" }
    get "/subscriptions/#{@subscription.id}/events/new"

    assert_response :success
    assert_select "input#event_actor_name[data-autocomplete-target='input']"
    assert_select "input#event_tags_list[data-autocomplete-target='input']"
    assert_select "div[data-controller='autocomplete'][data-autocomplete-items-value]", minimum: 2
  end

  test "event form keeps autocomplete lists inside their controllers in the parsed DOM" do
    post "/session", params: { user_name: @user.user_name, password: "testing" }
    get "/subscriptions/#{@subscription.id}/events/new"

    assert_response :success
    doc = Nokogiri::HTML(@response.body)
    lists = doc.css("ul[data-autocomplete-target='list']")
    assert lists.any?, "expected autocomplete dropdowns in the event form"

    lists.each do |list|
      controller = list.ancestors("[data-controller~='autocomplete']").first
      assert controller, "expected autocomplete list to stay inside its controller element"
      assert controller.at_css("input[data-autocomplete-target='input']"),
        "expected controller element to hold both the input and its list"
      # Browsers eject a <ul> from inside a <p>, which would strand the list
      # outside its controller: the controller must be a <div> outside any <p>.
      assert_equal "div", controller.name,
        "expected autocomplete controller to be a <div> so the <ul> stays nested"
      assert_empty controller.ancestors("p"),
        "expected autocomplete controller holding a <ul> to sit outside any <p>"
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
