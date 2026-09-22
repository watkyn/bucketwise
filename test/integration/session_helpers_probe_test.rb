require "test_helper"

class SessionHelpersProbeTest < ActionDispatch::IntegrationTest
  test "sign_in lands logged in" do
    sign_in :john
    follow_redirect!
    assert_response :success
  end

  test "sign_out clears session" do
    sign_in :john
    sign_out
    assert_redirected_to new_session_path
  end

  test "basic_auth_headers authenticates API" do
    get "/subscriptions.json", headers: basic_auth_headers(:john, password: "testing")
    assert_response :success
  end

  test "basic_auth_headers rejects bad password" do
    get "/subscriptions.json", headers: basic_auth_headers(:john, password: "wrong")
    assert_response :unauthorized
  end

  test "sign_in with bad password leaves session empty" do
    user = users(:john)
    post session_path, params: { user_name: user.user_name, password: "nope" }
    assert_redirected_to new_session_path
    follow_redirect!
    assert_response :success
  end
end
