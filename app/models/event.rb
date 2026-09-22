class Event < ApplicationRecord
  belongs_to :subscription, optional: true
  belongs_to :user, optional: true
  belongs_to :actor, optional: true

  has_many :line_items, dependent: :destroy do
    def for_role(name)
      name = name.to_s
      to_a.select { |item| item.role == name }
    end
  end

  has_many :account_items, dependent: :destroy

  has_many :tagged_items, dependent: :destroy do
    def partial
      @partial ||= to_a.select { |item| item.amount != proxy_association.owner.value }
    end

    def whole
      @whole ||= to_a.select { |item| item.amount == proxy_association.owner.value }
    end
  end

  has_many :tags, through: :tagged_items

  alias_method :original_line_items_assignment, :line_items=
  alias_method :original_tagged_items_assignment, :tagged_items=

  before_save :normalize_actor_name
  after_save :realize_line_items, :realize_tagged_items

  validates :actor_name, presence: true
  validates :occurred_on, presence: true
  validate :line_item_validations

  attr_accessor :amount

  def balance
    @balance ||= account_items.sum(:amount) || 0
  end

  def value
    case role
    when :expense, :deposit then balance.abs
    when :transfer then account_items.first.amount.abs
    when :reallocation then line_items.for_role(:primary).first.amount.abs
    else raise "cannot compute value of line item with role #{role.inspect}"
    end
  end

  def account_for(role)
    role = role.to_s
    item = line_items.detect { |item| item.role == role }
    return item ? item.account : nil
  end

  def line_items=(list)
    if list.is_a?(Array) && list.any? { |item| item.is_a?(Hash) }
      @line_items_to_realize = list.map { |h| h.deep_symbolize_keys rescue h }
      # Normalize keys to symbols for consistency
      @line_items_to_realize = @line_items_to_realize.map do |h|
        h.each_with_object({}) { |(k,v), m| m[k.to_sym] = v }
      end
    else
      original_line_items_assignment(list)
    end
  end

  def tagged_items=(list)
    if list.is_a?(Array) && list.any? { |item| item.is_a?(Hash) }
      @tagged_items_to_realize = list.map { |h| h.is_a?(Hash) ? h.each_with_object({}) { |(k,v), m| m[k.to_sym] = v } : h }
    else
      original_tagged_items_assignment(list)
    end
  end

  # delete all stuff, which is account_items and line_items
  def das
    line_items.delete_all
    account_items.delete_all
    delete
  end

  def role=(role)
    unless %w[deposit expense reallocation transfer].include?(role.to_s)
      raise ArgumentError, "invalid role: #{role.inspect}"
    end
    @role = role.to_sym
  end

  def role
    @role ||= if balance > 0
        :deposit
      elsif balance < 0
        :expense
      elsif account_items.length == 1
        :reallocation
      else
        :transfer
      end
  end

  def as_json(options={})
    methods = Array(options[:methods]).dup
    # Computed methods assume persisted account_items/line_items; unsaved
    # template events (GET events#new) serialize plain attributes instead.
    methods |= [:balance, :value, :role] if persisted?
    methods << :amount if amount
    super(options.merge(methods: methods))
  end

  # Build placeholder line_items/tagged_items for unsaved events so the JSON
  # "new" template response matches the shape the old XML API returned.
  def build_template_line_items
    return self unless new_record?
    return self if line_items.any?

    case role
    when :deposit
      line_items.build(role: "deposit", amount: 1000)
    when :expense
      line_items.build(role: "payment_source", amount: -1000)
      line_items.build(role: "credit_options", amount: -1000)
      line_items.build(role: "aside", amount: 1000)
    when :reallocation
      line_items.build(role: "primary")
      line_items.build(role: "reallocate_from | reallocate_to")
    when :transfer
      line_items.build(role: "transfer_from", amount: -1000)
      line_items.build(role: "transfer_to", amount: 1000)
    end
    tagged_items.build if tagged_items.empty?
    self
  end

  protected

    def line_item_validations
      if @line_items_to_realize
        if @line_items_to_realize.empty?
          errors.add(:line_items, "must be provided")
        else
          ensure_line_item_roles_are_valid
          role = ensure_line_items_use_consistent_roles
          case role
          when :expense then ensure_expense_is_valid
          when :deposit then ensure_deposit_is_valid
          when :transfer then ensure_transfer_is_valid
          when :reallocation then ensure_reallocation_is_valid
          end
        end
      elsif new_record?
        errors.add(:line_items, "must be provided")
      end
    end

    def normalize_actor_name
      if actor_name.present? && subscription
        self.actor = Actor.normalize_for(subscription, actor_name)
      end
    end

    def realize_line_items
      if @line_items_to_realize
        line_items.destroy_all
        account_items.destroy_all

        summaries = Hash.new(0)
        @line_items_to_realize.each do |item|
          item = item.dup
          account = subscription.accounts.find(item[:account_id] || item["account_id"])

          bucket_id = item.delete(:bucket_id) || item.delete("bucket_id")
          # Ensure bucket_id is string for regex matching
          bucket_id_str = bucket_id.to_s
          item[:bucket] = if bucket_id_str =~ /\An:(.*)/
            account.buckets.find_by(name: $1) || account.buckets.create(name: $1, author: user)
          elsif bucket_id_str =~ /\Ar:(.*)/
            account.buckets.for_role($1, user)
          else
            account.buckets.find(bucket_id)
          end

          # Remove string keys duplicates
          item = item.slice(:account_id, :bucket, :amount, :role, :account)
          # Handle amount as integer
          item[:amount] = item[:amount].to_i if item[:amount]
          created = line_items.create(item.merge(occurred_on: occurred_on))
          summaries[account] += created.amount
        end

        summaries.each do |account, amount|
          account_items.create(account: account, amount: amount, occurred_on: occurred_on)
        end

        @line_items_to_realize = nil
      end
    end

    def realize_tagged_items
      if @tagged_items_to_realize
        tagged_items.destroy_all

        @tagged_items_to_realize.each do |item|
          item = item.dup
          tag_id_val = item[:tag_id] || item["tag_id"]
          if tag_id_val.to_s =~ /\An:(.*)/
            item[:tag_id] = subscription.tags.find_or_create_by(name: $1).id
          else
            subscription.tags.find(tag_id_val)
            item[:tag_id] = tag_id_val
          end
          # Ensure amount handling
          item = item.slice(:tag_id, :amount, :tag)
          tagged_items.create(item.merge(occurred_on: occurred_on))
        end

        @tagged_items_to_realize = nil
      end
    end

  private

    ROLE_FROM_LINE_ITEM = {
      "payment_source"  => :expense,
      "credit_options"  => :expense,
      "aside"           => :expense,
      "deposit"         => :deposit,
      "transfer_from"   => :transfer,
      "transfer_to"     => :transfer,
      "reallocate_from" => :reallocation,
      "reallocate_to"   => :reallocation
    }

    def ensure_line_item_roles_are_valid
      @line_items_to_realize.each do |item|
        role_val = item[:role] || item["role"]
        if role_val.blank?
          errors.add(:line_item, "is missing the required `role' attribute")
          return false
        elsif !LineItem::VALID_ROLES.include?(role_val.to_s)
          errors.add(:line_item, "contains unrecognized role #{role_val.inspect}")
          return false
        end
      end
      true
    end

    def ensure_line_items_use_consistent_roles
      roles = @line_items_to_realize.map { |item| (item[:role] || item["role"]).to_s }
      primary = roles.select { |role| role == "primary" }

      if primary.length > 1
        errors.add :line_items, "may include at most one `primary' role (#{primary.length} found)"
        return false
      end

      aside = roles.select { |role| role == "aside" }
      if aside.length > 1
        errors.add :line_items, "may include at most one `aside' role (#{aside.length} found)"
        return false
      end

      discriminant = roles.detect { |role| role != "primary" }
      if discriminant.nil?
        errors.add :line_items, "must include at least one non-primary role"
        return false
      end

      illegal = roles - (LineItem::VALID_ROLE_GROUPS[discriminant] || [])
      if illegal.any?
        errors.add :line_items, "include mismatched roles: #{discriminant.inspect} cannot accompany #{illegal.inspect}"
        return false
      end

      ROLE_FROM_LINE_ITEM[discriminant]
    end

    def ensure_expense_is_valid
      unless @line_items_to_realize.any? { |item| (item[:role] || item["role"]).to_s == "payment_source" }
        errors.add :line_items, "must include a payment_source role for expense scenarios"
        return false
      end
      payment = credit = aside = 0
      @line_items_to_realize.each do |item|
        case (item[:role] || item["role"]).to_s
        when "payment_source" then payment += (item[:amount] || item["amount"]).to_i
        when "credit_options" then credit += (item[:amount] || item["amount"]).to_i
        when "aside"          then aside += (item[:amount] || item["amount"]).to_i
        end
      end
      if payment >= 0
        errors.add :line_items, "in payment_source role must have a negative amount"
        return false
      elsif @line_items_to_realize.any? { |item| (item[:role] || item["role"]).to_s == "credit_options" }
        if credit >= 0
          errors.add :line_items, "in credit_options role must have a negative amount"
          return false
        elsif aside <= 0
          errors.add :line_items, "in aside role must have a positive amount"
          return false
        elsif payment != credit
          errors.add :line_items, "for payment_source and credit_options must sum to identical balance"
          return false
        elsif payment.abs != aside
          errors.add :line_items, "for payment_source and aside must balance"
          return false
        end
      end
      true
    end

    def ensure_deposit_is_valid
      if @line_items_to_realize.any? { |item| (item[:amount] || item["amount"]).to_i <= 0 }
        errors.add :line_items, "for deposit must all have positive amounts"
        return false
      end
      true
    end

    def ensure_transfer_is_valid
      roles = @line_items_to_realize.map { |item| (item[:role] || item["role"]).to_s }.uniq.sort
      if roles != %w[transfer_from transfer_to]
        errors.add :line_items, "must contain both transfer_from and transfer_to roles in a transfer scenario"
        return false
      end
      accounts = @line_items_to_realize.map { |item| (item[:account_id] || item["account_id"]).to_i }
      if accounts.uniq.length != 2
        errors.add :line_items, "must reference exactly two accounts in a transfer scenario"
        return false
      end
      balances = @line_items_to_realize.inject(Hash.new(0)) do |map, item|
        map[(item[:account_id] || item["account_id"]).to_i] += (item[:amount] || item["amount"]).to_i
        map
      end
      if balances.values.sum != 0
        errors.add :line_items, "must have a zero balance in a transfer scenario"
        return false
      end
      @line_items_to_realize.each do |item|
        role_val = (item[:role] || item["role"]).to_s
        amt = (item[:amount] || item["amount"]).to_i
        if role_val == "transfer_from" && amt >= 0
          errors.add :line_item, "with transfer_from role must have a negative amount"
          return false
        elsif role_val == "transfer_to" && amt <= 0
          errors.add :line_item, "with transfer_to role must have a positive amount"
          return false
        end
      end
      true
    end

    def ensure_reallocation_is_valid
      unless @line_items_to_realize.any? { |item| (item[:role] || item["role"]).to_s == "primary" }
        errors.add :line_items, "must include a `primary' role for bucket reallocation scenario"
        return false
      end
      accounts = @line_items_to_realize.map { |item| (item[:account_id] || item["account_id"]).to_i }.uniq
      if accounts.length != 1
        errors.add :line_items, "for bucket reallocation scenario must reference exactly one account"
        return false
      end
      balances = @line_items_to_realize.inject(Hash.new(0)) do |map, item|
        map[(item[:role] || item["role"]).to_s] += (item[:amount] || item["amount"]).to_i
        map
      end
      if balances.values.sum != 0
        errors.add :line_items, "must balance to zero for bucket reallocation scenario"
        return false
      end
      true
    end
end
