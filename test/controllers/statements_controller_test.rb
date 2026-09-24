require "test_helper"

class StatementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  test "index for inaccessible account should 404" do
    get account_statements_path(accounts(:tim_checking))
    assert_response :not_found
  end

  test "index should list only balanced statements" do
    get account_statements_path(accounts(:john_checking))

    assert_response :ok
    assert_select "h2", text: /Previous Statements/
    assert_select "ul li", 1
    assert_select "ul li a[href=?]", statement_path(statements(:john)),
      text: statements(:john).occurred_on.strftime("%Y-%m-%d")
    assert_select "ul li a[href=?]", statement_path(statements(:john_pending)), 0
  end

  test "new for inaccessible account should 404" do
    get new_account_statement_path(accounts(:tim_checking))
    assert_response :not_found
  end

  test "new should build template record and render" do
    assert_no_difference -> { Statement.count } do
      get new_account_statement_path(accounts(:john_checking))
    end

    assert_response :ok
    assert_select "h2", text: /Let's reconcile your Checking account/
    assert_select "form[action=?]", account_statements_path(accounts(:john_checking))
    assert_select "input[name=?]", "statement[occurred_on]"
  end

  test "create for inaccessible account should 404" do
    assert_no_difference -> { Statement.count } do
      post account_statements_path(accounts(:tim_checking)),
        params: { statement: { occurred_on: Date.current, ending_balance: 1234_56 } }
      assert_response :not_found
    end
  end

  test "create should create new record and redirect to edit" do
    assert_difference -> { accounts(:john_checking).reload.statements.size } do
      post account_statements_path(accounts(:john_checking)),
        params: { statement: { occurred_on: Date.current, ending_balance: 1234_56 } }
    end

    statement = accounts(:john_checking).statements.find_by!(ending_balance: 1234_56)
    assert_equal Date.current, statement.occurred_on
    assert_redirected_to edit_statement_path(statement)
  end

  test "show for inaccessible statement should 404" do
    get statement_path(statements(:tim))
    assert_response :not_found
  end

  test "show should load statement record and render" do
    get statement_path(statements(:john))

    assert_response :ok
    assert_select "h2", text: /Statement for period ending #{statements(:john).occurred_on.strftime("%Y-%m-%d")}/
    assert_select "#balance", text: "$992.25"
  end

  test "edit for inaccessible statement should 404" do
    get edit_statement_path(statements(:tim))
    assert_response :not_found
  end

  test "edit should load statement record and render" do
    get edit_statement_path(statements(:john))

    assert_response :ok
    assert_select "h2", text: /Balance your statement/
    assert_select "form[action=?]", statement_path(statements(:john))
    assert_select "td#starting_balance", text: "$0.00"
  end

  test "edit hides congratulations and offers save-for-later while unbalanced" do
    assert_not statements(:john_pending).balanced?

    get edit_statement_path(statements(:john_pending))

    assert_response :ok
    assert_select "#balanced.hidden", count: 1
    assert_select "#actions", count: 1
    assert_select "#actions.hidden", count: 0
  end

  test "edit shows congratulations and close-out once balanced" do
    statement = accounts(:john_checking).statements.create!(
      occurred_on: Date.current, ending_balance: statements(:john_pending).starting_balance)
    assert statement.balanced?

    get edit_statement_path(statement)

    assert_response :ok
    assert_select "#balanced", count: 1
    assert_select "#balanced.hidden", count: 0
    assert_select "#actions.hidden", count: 1
  end

  test "update for inaccessible statement should 404" do
    put statement_path(statements(:tim)),
      params: { statement: { occurred_on: statements(:tim).occurred_on,
        ending_balance: statements(:tim).ending_balance,
        cleared: [account_items(:tim_checking_starting_balance).id] } }

    assert_response :not_found
    assert statements(:tim).reload.account_items.empty?
  end

  test "update should load statement and update statement and redirect" do
    assert statements(:john_pending).account_items.empty?

    put statement_path(statements(:john_pending)),
      params: { statement: { occurred_on: statements(:john_pending).occurred_on,
        ending_balance: statements(:john_pending).ending_balance,
        cleared: [account_items(:john_lunch_again_checking).id] } }

    assert_redirected_to account_path(statements(:john_pending).account)
    assert_equal [account_items(:john_lunch_again_checking)],
      statements(:john_pending).reload.account_items
  end

  test "update accepts a negative ending balance for overdrawn accounts" do
    put statement_path(statements(:john_pending)),
      params: { statement: { ending_balance: "-100.00" } }

    assert_redirected_to account_path(statements(:john_pending).account)
    assert_equal(-100_00, statements(:john_pending).reload.ending_balance)
  end

  test "destroy for inaccessible statement should 404" do
    assert_no_difference -> { Statement.count } do
      delete statement_path(statements(:tim))
      assert_response :not_found
    end
  end

  test "destroy should load and destroy statement and redirect" do
    assert_difference -> { Statement.count }, -1 do
      delete statement_path(statements(:john))
    end

    assert_redirected_to account_path(statements(:john).account)
    assert_not Statement.exists?(statements(:john).id)
  end
end
