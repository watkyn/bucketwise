require "test_helper"
require "rake"

class UserTasksTest < ActiveSupport::TestCase
  def invoke_task(name)
    Rails.application.load_tasks unless Rake::Task.task_defined?("user:create")
    task = Rake::Task[name]
    task.reenable
    task.invoke
  end

  def with_env(vars)
    old = {}
    vars.each { |k, v| old[k] = ENV[k]; v.nil? ? ENV.delete(k) : ENV[k] = v }
    yield
  ensure
    old.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  test "user:create creates a user from env vars without prompting" do
    with_env("NAME" => "Task User", "EMAIL" => "task@example.com",
             "USERNAME" => "task.user", "PASSWORD" => "secret123") do
      assert_difference ["User.count", "Subscription.count"], 1 do
        invoke_task("user:create")
      end
    end

    user = User.find_by!(user_name: "task.user")
    assert_equal user, User.authenticate("task.user", "secret123")
    assert_equal user, user.subscriptions.first.owner
    assert_includes user.subscriptions.first.users, user
  end

  test "user:create skips the subscription with SKIP_SUBSCRIPTION=1" do
    with_env("NAME" => "Lone User", "EMAIL" => "lone@example.com",
             "USERNAME" => "lone.user", "PASSWORD" => "secret123",
             "SKIP_SUBSCRIPTION" => "1") do
      assert_difference -> { User.count }, 1 do
        assert_no_difference -> { Subscription.count } do
          invoke_task("user:create")
        end
      end
    end

    assert_empty User.find_by!(user_name: "lone.user").subscriptions
  end

  test "user:list runs on Rails 8 without User.find(:all)" do
    with_env("PAGE" => "0") do
      assert_nothing_raised do
        invoke_task("user:list")
      end
    end
  end

  test "user:show finds a user by USERNAME" do
    user = users(:john)
    with_env("USERNAME" => user.user_name) do
      assert_output(/##{user.id}: "#{user.name}" <#{user.email}>/) do
        invoke_task("user:show")
      end
    end
  end
end
