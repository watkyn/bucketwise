class Bucket < ApplicationRecord
  RECENT_WINDOW_SIZE = 10

  Temp = Struct.new(:id, :name, :role, :balance)

  belongs_to :account
  belongs_to :author, class_name: "User", foreign_key: "user_id", optional: true

  has_many :line_items, dependent: :nullify

  validates :name, presence: true
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }

  def self.filtered(filter)
    filter_scope(filter)
  end

  # Keep old name as alias but handle Ruby 3 Enumerable conflict
  def self.filter(filter_obj=nil, &block)
    if block_given?
      super
    else
      filter_scope(filter_obj)
    end
  end

  def self.filter_scope(filter)
    return all unless filter.any?

    scope = left_joins(:line_items)
            .select("buckets.*, SUM(line_items.amount) as computed_balance")
            .group("buckets.id")

    conditions = []
    binds = []

    if filter.from?
      conditions << "line_items.occurred_on >= ?"
      binds << filter.from
    end

    if filter.to?
      conditions << "line_items.occurred_on <= ?"
      binds << filter.to
    end

    if filter.by_type?
      roles = []
      if filter.expenses?
        roles << 'payment_source'
        roles << 'transfer_from'
        roles << 'credit_options'
      end
      if filter.deposits?
        roles << 'deposit'
        roles << 'transfer_to'
      end
      if filter.reallocations?
        roles << 'primary'
        roles << 'aside'
        roles << 'credit_options'
        roles << 'reallocate_from'
        roles << 'reallocate_to'
      end
      conditions << "line_items.role IN (?)"
      binds << roles.uniq
    end

    if conditions.any?
      scope = scope.where([conditions.join(" AND "), *binds])
    end

    scope
  end

  # For historical named_scope compatibility
  def self.options_for_filter(filter)
    # Return relation-like hash for backwards compat, but prefer filter_scope
    return {} unless filter.any?
    filter_scope(filter)
  end

  def self.default
    Temp.new("r:default", "General", "default", 0)
  end

  def self.aside
    Temp.new("r:aside", "Aside", "aside", 0)
  end

  def self.template
    new(name: "Bucket name (e.g. Groceries)", role: "aside | default | nil")
  end

  def self.recent(n=RECENT_WINDOW_SIZE)
    order(updated_at: :desc).limit(n).to_a.sort_by(&:name)
  end

  def balance
    (self[:computed_balance] || self[:balance]).to_i
  end

  def assimilate(bucket)
    if bucket == self
      raise ArgumentError, "cannot assimilate self"
    end

    if bucket.account_id != account_id
      raise ArgumentError, "cannot assimilate bucket from different account"
    end

    old_id = bucket.id

    Bucket.transaction do
      LineItem.where(bucket_id: old_id).update_all(bucket_id: id)
      update_column(:balance, balance + bucket.balance)
      bucket.destroy
    end
  end

  def as_json(options={})
    if new_record?
      options[:only] = %w[name role]
    end
    super(options)
  end
end
