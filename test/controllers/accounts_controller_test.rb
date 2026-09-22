require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  test "show should 404 when when user without permissions requests page" do
    get account_path(accounts(:tim_checking))
    assert_response :not_found
  end

  test "new should 404 when user without permissions requests page" do
    get new_subscription_account_path(subscriptions(:tim))
    assert_response :not_found
  end

  test "create should 404 when when user without permissions requests page" do
    assert_no_difference -> { Account.count } do
      post subscription_accounts_path(subscriptions(:tim)),
        params: { account: { name: "Savings", role: "saving" } }
      assert_response :not_found
    end
  end

  test "show should load account and subscription and render page" do
    account = accounts(:john_checking)

    get account_path(account)

    assert_response :ok
    assert_select "h2#name_account_#{account.id}", text: /Checking/
    assert_select ".navigation a[href=?]", subscription_path(subscriptions(:john))
    assert_select ".navigation a[href=?]", account_buckets_path(account)
  end

  test "new should load subscription and render page" do
    get new_subscription_account_path(subscriptions(:john))

    assert_response :ok
    assert_select "div#new_account"
    assert_select "form#new_account_form[action=?]", subscription_accounts_path(subscriptions(:john))
    assert_select "input[name=?]", "account[name]"
  end

  test "create should load subscription and create account and redirect" do
    assert_difference -> { subscriptions(:john).accounts.count } do
      post subscription_accounts_path(subscriptions(:john)),
        params: { account: { name: "Mortgage", role: "" } }
      assert_redirected_to subscription_url(subscriptions(:john))
    end

    account = subscriptions(:john).accounts.find_by!(name: "Mortgage")
    assert_equal users(:john), account.author
    assert_equal "", account.role
  end

  test "create with invalid record should render 'new' action" do
    assert_no_difference -> { Account.count } do
      post subscription_accounts_path(subscriptions(:john)),
        params: { account: { name: "Checking", role: "checking" } }

      assert_response :unprocessable_entity
      assert_select "form#new_account_form[action=?]", subscription_accounts_path(subscriptions(:john))
      assert_select "fieldset.errors li", text: /already been taken/
    end
  end

  test "destroy should 404 when user without permission requests page" do
    assert_no_difference -> { Account.count } do
      delete account_path(accounts(:tim_checking))
      assert_response :not_found
    end
  end

  test "destroy should remove account and redirect" do
    assert_difference -> { Account.count }, -1 do
      delete account_path(accounts(:john_mastercard))
      assert_redirected_to subscription_url(subscriptions(:john))
    end
  end

  test "update should 404 when user without permissions requests page" do
    put account_path(accounts(:tim_checking)),
      params: { account: { name: "Hi!" } }, as: :turbo_stream

    assert_response :not_found
    assert_equal "Checking", accounts(:tim_checking).reload.name
  end

  test "update should change account name and render javascript" do
    account = accounts(:john_checking)

    put account_path(account), params: { account: { name: "Hi!" } }, as: :turbo_stream

    assert_response :ok
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_includes @response.body, %(<turbo-stream action="replace" target="name_account_#{account.id}">)
    assert_includes @response.body, "Hi!"
    assert_equal "Hi!", account.reload.name
  end

  test "change_password should update the signed-in user's password" do
    user = users(:john)

    post change_password_path, params: { new_password: "newtesting" }

    assert_redirected_to root_path
    assert_equal user, User.authenticate(user.user_name, "newtesting")
    assert_nil User.authenticate(user.user_name, "testing")
  end

  # == API tests ========================================================================

  test "index via API should return account list" do
    get subscription_accounts_path(subscriptions(:john), format: :json)

    assert_response :success
    assert_equal subscriptions(:john).accounts.length, @response.parsed_body.length
  end

  test "show via API should return account record" do
    get account_path(accounts(:john_checking), format: :json)

    assert_response :success
    assert_equal accounts(:john_checking).id, @response.parsed_body["id"]
  end

  test "new via API should return a template JSON response" do
    get new_subscription_account_path(subscriptions(:john), format: :json)

    assert_response :success
    json = @response.parsed_body
    assert json
    assert_not json["id"]
  end

  test "create via API should return 422 with error messages when validations fail" do
    post subscription_accounts_path(subscriptions(:john), format: :json),
      params: { account: { name: "Checking", role: "" } }

    assert_response :unprocessable_entity
    assert @response.parsed_body.any?
  end

  test "create via API should create record and respond with 201" do
    assert_difference -> { subscriptions(:john).accounts.count } do
      post subscription_accounts_path(subscriptions(:john), format: :json),
        params: { account: { name: "Mortgage", role: "" } }

      assert_response :created
      assert @response.headers["Location"]
    end
  end

  test "update via API with validation errors should respond with 422" do
    put account_path(accounts(:john_checking), format: :json),
      params: { account: { name: "Mastercard" } }

    assert_response :unprocessable_entity
    assert @response.parsed_body.any?
  end

  test "update via API should update record and respond with 200" do
    put account_path(accounts(:john_checking), format: :json),
      params: { account: { name: "Hi!" } }

    assert_response :success
    assert_equal "Hi!", @response.parsed_body["name"]
  end

  test "destroy via API should remove record and respond with 200" do
    assert_difference -> { Account.count }, -1 do
      delete account_path(accounts(:john_mastercard), format: :json)
      assert_response :success
    end
  end
end
