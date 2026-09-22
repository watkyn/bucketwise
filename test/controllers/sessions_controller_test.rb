require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new should render login page" do
    get new_session_path

    assert_response :ok
    assert_select "form[action=?]", session_path
    assert_select "input[name=?]", "user_name"
    assert_select "input[name=?]", "password"
  end

  test "create should redirect to login page on bad user name" do
    post session_path, params: { user_name: "jimjim", password: "whatever" }
    assert_redirected_to new_session_path

    follow_redirect!
    assert_response :ok
    assert_includes @response.body, "The user name or password you gave was incorrect."

    # A subsequent request to a protected page proves no session was established.
    get subscription_path(subscriptions(:john))
    assert_redirected_to new_session_path
  end

  test "create should redirect to login page on bad password" do
    post session_path, params: { user_name: "jjohnson", password: "whatever" }
    assert_redirected_to new_session_path

    follow_redirect!
    assert_response :ok
    assert_includes @response.body, "The user name or password you gave was incorrect."

    # A subsequent request to a protected page proves no session was established.
    get subscription_path(subscriptions(:john))
    assert_redirected_to new_session_path
  end

  test "create should redirect to subscription page on success when only one subscription" do
    post session_path, params: { user_name: "ttaylor", password: "testing" }
    assert_redirected_to subscription_path(subscriptions(:tim))

    follow_redirect!
    assert_response :ok
    assert_select "#accounts_summary a[href=?]", account_path(accounts(:tim_checking)),
      text: "Checking"
  end

  test "create should redirect to subscription index on success when multiple subscriptions" do
    post session_path, params: { user_name: "jjohnson", password: "testing" }
    assert_redirected_to subscriptions_path

    follow_redirect!
    assert_response :ok
    assert_select "li#subscription_#{subscriptions(:john).id}"
    assert_select "li#subscription_#{subscriptions(:john_family).id}"
    assert_select "li#subscription_#{subscriptions(:tim).id}", 0
  end

  test "destroy should log the user out" do
    sign_in :john

    delete session_path
    assert_redirected_to new_session_path

    follow_redirect!
    assert_response :ok
    assert_includes @response.body, "You have been logged out."

    # A subsequent request to a protected page proves the session was cleared.
    get subscription_path(subscriptions(:john))
    assert_redirected_to new_session_path
  end
end
