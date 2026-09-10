class Subscription < ApplicationRecord
  DEFAULT_PAGE_SIZE = 5

  belongs_to :owner, class_name: "User"

  has_many :accounts, -> { order(:role, :name) }
  has_many :tags
  has_many :actors

  has_many :events do
    def recent(n=0, options={})
      size = (options[:size] || Subscription::DEFAULT_PAGE_SIZE).to_i
      n = n.to_i

      scope = self
      if options[:actor]
        scope = scope.joins("LEFT JOIN actors ON actors.id = events.actor_id")
                     .where("actors.sort_name = ?", Actor.normalize_name(options[:actor]))
      end

      records = scope.includes(:account_items)
                     .order(created_at: :desc)
                     .limit(size + 1)
                     .offset(n * size)
                     .to_a

      [records.length > size, records.first(size)]
    end

    def prepare(attrs={})
      event = build(role: attrs[:role], occurred_on: Date.current)

      case event.role
      when :reallocation
        event.actor_name = "Bucket reallocation"
        if attrs[:from]
          bucket = Bucket.find(attrs[:from])
          account = proxy_association.owner.accounts.find(bucket.account_id)
          event.line_items.build(role: "primary", account: account, bucket: bucket)
          event.line_items.build(role: "reallocate_from", account: account, bucket: account.buckets.default)
        elsif attrs[:to]
          bucket = Bucket.find(attrs[:to])
          account = proxy_association.owner.accounts.find(bucket.account_id)
          event.line_items.build(role: "primary", account: account, bucket: bucket)
          event.line_items.build(role: "reallocate_to", account: account, bucket: account.buckets.default)
        end
      end

      event
    end
  end

  has_many :user_subscriptions, dependent: :destroy
  has_many :users, through: :user_subscriptions

  # removes everything from the subscription, without deleting the subscription
  def clean
    transaction do
      LineItem.where(event_id: events.select(:id)).delete_all
      AccountItem.where(event_id: events.select(:id)).delete_all
      TaggedItem.where(event_id: events.select(:id)).delete_all

      Bucket.where(account_id: accounts.select(:id)).delete_all
      Statement.where(account_id: accounts.select(:id)).delete_all

      actors.delete_all
      events.delete_all
      accounts.delete_all
      tags.delete_all
    end
  end

  # an optimized destroy to avoid costly dependency cascades
  def destroy
    transaction do
      clean
      UserSubscription.where(subscription_id: id).delete_all
      self.class.where(id: id).delete_all
    end
  end
end
