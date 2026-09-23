require "test_helper"
require "rake"

Rails.application.load_tasks unless Rake::Task.task_defined?("demo:build")

class DemoBuildTest < ActionDispatch::IntegrationTest
  test "demo build creates a usable demo login" do
    task = Rake::Task["demo:build"]
    task.reenable

    assert_difference -> { User.count }, 2 do
      task.invoke
    end

    user = User.find_by!(user_name: "bw.demo")
    assert_equal user, User.authenticate("bw.demo", "demo")
    assert_predicate user.subscriptions.sole.accounts.find_by!(role: "credit-card").limit, :positive?

    post session_path, params: { user_name: "bw.demo", password: "demo" }
    assert_redirected_to subscription_path(user.subscriptions.sole)
  end
end
