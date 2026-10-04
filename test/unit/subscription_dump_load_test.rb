require "test_helper"
require "rake"
require "tmpdir"

class SubscriptionDumpLoadTest < ActiveSupport::TestCase
  def invoke_task(name)
    Rails.application.load_tasks unless Rake::Task.task_defined?("data:subscription:dump")
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

  def snapshot(subscription)
    {
      subscription: subscription.attributes,
      tags: subscription.tags.order(:id).map(&:attributes),
      accounts: subscription.accounts.order(:id).map(&:attributes),
      actors: subscription.actors.order(:id).map(&:attributes),
      events: subscription.events.order(:id).map(&:attributes),
      user_subscriptions: subscription.user_subscriptions.order(:id).map(&:attributes),
      statements: Statement.where(account_id: subscription.accounts.select(:id)).order(:id).map(&:attributes),
      buckets: Bucket.where(account_id: subscription.accounts.select(:id)).order(:id).map(&:attributes),
      line_items: LineItem.where(event_id: subscription.events.select(:id)).order(:id).map(&:attributes),
      account_items: AccountItem.where(event_id: subscription.events.select(:id)).order(:id).map(&:attributes),
      tagged_items: TaggedItem.where(event_id: subscription.events.select(:id)).order(:id).map(&:attributes)
    }
  end

  test "dump and load round-trips one subscription including its users" do
    subscription = subscriptions(:john)
    expected = snapshot(subscription)
    owner_attrs = subscription.owner.attributes
    member_ids = subscription.users.pluck(:id).sort

    Dir.mktmpdir do |dir|
      file = File.join(dir, "john.yml")

      with_env("ID" => subscription.id.to_s, "FILE" => file) do
        invoke_task("data:subscription:dump")
      end
      assert File.exist?(file), "expected dump file at #{file}"

      subscription.destroy
      assert_not Subscription.exists?(subscription.id)

      with_env("FILE" => file, "CONFIRM" => "1") do
        invoke_task("data:subscription:load")
      end

      restored = Subscription.find(subscription.id)
      assert_equal owner_attrs["user_name"], restored.owner.user_name
      assert_equal member_ids, restored.users.pluck(:id).sort

      actual = snapshot(restored)
      expected.each do |key, records|
        assert_equal records, actual[key], "mismatch in #{key}"
      end
    end
  end
end
