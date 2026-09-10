class Account < ApplicationRecord
  DEFAULT_BUCKET_NAME = "General"

  DEFAULT_LIMIT_VALUES = {
    critical: 100,
    high: 80,
    medium: 30,
    low: 0
  }

  belongs_to :subscription
  belongs_to :author, class_name: "User", foreign_key: "user_id", optional: true

  attr_accessor :starting_balance

  validates :name, presence: true
  validates :limit, presence: true, if: :credit_card?
  validates :name, uniqueness: { scope: :subscription_id, case_sensitive: false }

  has_many :buckets, dependent: :destroy do
    def for_role(role, user)
      role = role.downcase
      find_by(role: role) || create(name: role.capitalize, role: role, author: user)
    end

    def sorted
      sort_by(&:name)
    end

    def default
      detect { |bucket| bucket.role == "default" }
    end

    def with_defaults
      buckets = to_a.dup
      buckets << Bucket.default unless buckets.any? { |bucket| bucket.role == "default" }
      buckets << Bucket.aside unless buckets.any? { |bucket| bucket.role == "aside" }
      buckets
    end
  end

  has_many :line_items, dependent: :destroy
  has_many :statements, dependent: :destroy

  has_many :account_items, extend: CategorizedItems

  after_create :create_default_buckets, :set_starting_balance

  def self.template
    new(name: "Account name (e.g. Checking)", role: "checking | credit-card | nil",
      starting_balance: { amount: 0, occurred_on: Date.current })
  end

  def credit_card?
    role == 'credit-card'
  end

  def checking?
    role == 'checking'
  end

  def available_balance
    @available_balance ||= balance - unavailable_balance
  end

  def unavailable_balance
    @unavailable_balance ||= begin
      aside = buckets.detect { |bucket| bucket.role == 'aside' }
      aside && aside.balance > 0 ? aside.balance : 0
    end
  end

  def has_mismatch_totals?
    balance != buckets.sum(:balance)
  end

  def destroy
    transaction do
      cleanup_account_items
      cleanup_line_items
      cleanup_buckets
      cleanup_tagged_items
      cleanup_events

      self.class.where(id: id).delete_all
    end
  end

  def as_json(options={})
    if new_record?
      options[:only] = %w[name role]
      if starting_balance
        options[:methods] = Array(options[:methods]) + [:starting_balance_json]
      end
    end
    super(options)
  end

  def starting_balance_json
    starting_balance
  end

  protected

    def create_default_buckets
      buckets.create(name: DEFAULT_BUCKET_NAME, role: "default", author: author)
    end

    def set_starting_balance
      if starting_balance && !starting_balance[:amount].to_i.zero?
        amount = starting_balance[:amount].to_i
        role = amount > 0 ? "deposit" : "payment_source"
        subscription.events.create(
          occurred_on: starting_balance[:occurred_on],
          actor_name: "Starting balance",
          line_items: [{ account_id: id, bucket_id: buckets.default.id, amount: amount, role: role }],
          user: author
        )
        reload
      end
    end

  private

    def cleanup_line_items
      LineItem.where(account_id: id).delete_all
    end

    def cleanup_account_items
      items = account_items.includes(event: [:line_items, :account_items]).to_a

      items.each do |item|
        event = item.event
        next unless event.account_items.length > 1

        case event.role
        when :transfer
          event.line_items.update_all(role: (item.amount < 0 ? 'deposit' : 'payment_source'))
        when :expense
          if event.account_for(:payment_source) == self
            event.line_items.where(role: 'aside').update_all(role: 'primary')
            event.line_items.where(role: 'credit_options').update_all(role: 'reallocate_to')
          end
        end
      end

      AccountItem.where(account_id: id).delete_all
    end

    def cleanup_buckets
      Bucket.where(account_id: id).delete_all
    end

    def cleanup_tagged_items
      tagged_items = TaggedItem.find_by_sql([<<-SQL.squish, subscription_id])
        SELECT t.* FROM tagged_items t LEFT JOIN events e ON t.event_id = e.id
         WHERE e.subscription_id = ?
           AND NOT EXISTS (
            SELECT * FROM account_items a WHERE a.event_id = e.id)
      SQL
      tagged_items.each { |item| item.destroy }
    end

    def cleanup_events
      self.class.connection.execute(<<-SQL.squish)
        DELETE FROM events
         WHERE subscription_id = #{self.class.connection.quote(subscription_id)}
           AND NOT EXISTS (
            SELECT * FROM account_items a WHERE a.event_id = events.id)
      SQL
    end
end
