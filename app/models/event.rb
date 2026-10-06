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
      @line_items_to_realize = list.map { |item| item.to_h.symbolize_keys }
    else
      original_line_items_assignment(list)
    end
  end

  def tagged_items=(list)
    if list.is_a?(Array) && list.any? { |item| item.is_a?(Hash) }
      @tagged_items_to_realize = list.map { |item| item.to_h.symbolize_keys }
    else
      original_tagged_items_assignment(list)
    end
  end

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
    methods |= [:balance, :value, :role] if persisted?
    methods << :amount if amount
    super(options.merge(methods: methods))
  end

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
          account = subscription.accounts.find(item[:account_id])

          bucket_id = item.delete(:bucket_id).to_s
          item[:bucket] = if (match = bucket_id.match(/\An:(.*)/))
            name = match[1]
            account.buckets.where("LOWER(name) = ?", name.downcase).first ||
              account.buckets.create(name: name, author: user)
          elsif (match = bucket_id.match(/\Ar:(.*)/))
            account.buckets.for_role(match[1], user)
          else
            account.buckets.find(bucket_id)
          end

          item = item.slice(:account_id, :bucket, :amount, :role, :account)
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
          tag_id_val = item[:tag_id].to_s
          if tag_id_val =~ /\An:(.*)/
            item[:tag_id] = subscription.tags.find_or_create_by(name: $1).id
          else
            subscription.tags.find(tag_id_val)
            item[:tag_id] = tag_id_val
          end
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
        if item[:role].blank?
          errors.add(:line_item, "is missing the required `role' attribute")
          return false
        elsif !LineItem::VALID_ROLES.include?(item[:role].to_s)
          errors.add(:line_item, "contains unrecognized role #{item[:role].inspect}")
          return false
        end
      end
      true
    end

    def ensure_line_items_use_consistent_roles
      roles = @line_items_to_realize.map { |item| item[:role].to_s }
      primary = roles.select { |role| role == "primary" }

      if primary.length > 1
        errors.add :line_items, "may include at most one `primary' role (#{primary.length} found)"
        return false
      end

      # Aside reserves split one per repayment account.
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
      unless pending_items_for_role("payment_source").any?
        errors.add :line_items, "must include a payment_source role for expense scenarios"
        return false
      end
      return false unless ensure_expense_leg_signs_are_valid
      return true unless pending_items_for_role("credit_options").any?

      payment = pending_amount_for_role("payment_source")
      credit = pending_amount_for_role("credit_options")
      aside = pending_amount_for_role("aside")

      if payment != credit
        errors.add :line_items, "for payment_source and credit_options must sum to identical balance"
        return false
      elsif payment.abs != aside
        errors.add :line_items, "for payment_source and aside must balance"
        return false
      end

      ensure_repayment_accounts_balance
    end

    # Check signs per leg so split legs cannot cancel out.
    def ensure_expense_leg_signs_are_valid
      @line_items_to_realize.each do |item|
        role = item[:role].to_s
        amount = item[:amount].to_i

        if (role == "payment_source" || role == "credit_options") && amount >= 0
          errors.add :line_items, "in #{role} role must have a negative amount"
          return false
        elsif role == "aside" && amount <= 0
          errors.add :line_items, "in aside role must have a positive amount"
          return false
        end
      end

      true
    end

    # Each repayment account must net to zero to keep balances exact.
    def ensure_repayment_accounts_balance
      balances = Hash.new(0)
      @line_items_to_realize.each do |item|
        next if item[:role].to_s == "payment_source"
        balances[item[:account_id].to_i] += item[:amount].to_i
      end

      balances.each do |account_id, net|
        if net != 0
          errors.add :line_items, "repayment legs for account #{account_id} must net to zero"
          return false
        end
      end

      true
    end

    def ensure_deposit_is_valid
      if @line_items_to_realize.any? { |item| item[:amount].to_i <= 0 }
        errors.add :line_items, "for deposit must all have positive amounts"
        return false
      end
      true
    end

    def ensure_transfer_is_valid
      roles = @line_items_to_realize.map { |item| item[:role].to_s }.uniq.sort
      if roles != %w[transfer_from transfer_to]
        errors.add :line_items, "must contain both transfer_from and transfer_to roles in a transfer scenario"
        return false
      end
      accounts = @line_items_to_realize.map { |item| item[:account_id].to_i }
      if accounts.uniq.length != 2
        errors.add :line_items, "must reference exactly two accounts in a transfer scenario"
        return false
      end
      balances = @line_items_to_realize.inject(Hash.new(0)) do |map, item|
        map[item[:account_id].to_i] += item[:amount].to_i
        map
      end
      if balances.values.sum != 0
        errors.add :line_items, "must have a zero balance in a transfer scenario"
        return false
      end
      @line_items_to_realize.each do |item|
        role = item[:role].to_s
        amount = item[:amount].to_i
        if role == "transfer_from" && amount >= 0
          errors.add :line_item, "with transfer_from role must have a negative amount"
          return false
        elsif role == "transfer_to" && amount <= 0
          errors.add :line_item, "with transfer_to role must have a positive amount"
          return false
        end
      end
      true
    end

    def ensure_reallocation_is_valid
      unless pending_items_for_role("primary").any?
        errors.add :line_items, "must include a `primary' role for bucket reallocation scenario"
        return false
      end
      accounts = @line_items_to_realize.map { |item| item[:account_id].to_i }.uniq
      if accounts.length != 1
        errors.add :line_items, "for bucket reallocation scenario must reference exactly one account"
        return false
      end
      balances = @line_items_to_realize.inject(Hash.new(0)) do |map, item|
        map[item[:role].to_s] += item[:amount].to_i
        map
      end
      if balances.values.sum != 0
        errors.add :line_items, "must balance to zero for bucket reallocation scenario"
        return false
      end
      true
    end

    def pending_items_for_role(role)
      @line_items_to_realize.select { |item| item[:role].to_s == role }
    end

    def pending_amount_for_role(role)
      pending_items_for_role(role).sum { |item| item[:amount].to_i }
    end
end
