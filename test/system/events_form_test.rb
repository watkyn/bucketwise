require "application_system_test_case"

class EventsFormTest < ApplicationSystemTestCase
  test "clicking expense reveals the new event form without a full page navigation" do
    visit "/session/new"
    fill_in "user_name", with: "jjohnson"
    fill_in "password", with: "testing"
    click_button "Log into BucketWise"
    assert_no_current_path "/session/new"

    subscription = subscriptions(:john)
    visit subscription_path(subscription)

    assert_selector "#expense_link", visible: true
    path_before = page.current_path

    click_link "expense"

    assert_selector "#new_event", visible: true, wait: 5
    assert_equal path_before, page.current_path
  end
end
