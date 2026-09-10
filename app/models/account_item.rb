class AccountItem < ApplicationRecord
  include Pageable

  belongs_to :event, optional: true
  belongs_to :account, optional: true
  belongs_to :statement, optional: true

  after_create :increment_balance
  before_destroy :decrement_balance

  scope :uncleared, ->(args) {
    options = args.is_a?(Hash) ? args.dup : {}
    conditions = "statement_id IS NULL"
    parameters = []
    if options[:with]
      with_obj = options[:with]
      with_id = with_obj.is_a?(Statement) ? with_obj.id : with_obj
      conditions = "(#{conditions} OR statement_id = ?)"
      parameters << with_id
    end
    rel = where([conditions, *parameters])
    rel = rel.includes(options[:include]) if options[:include]
    rel.order(occurred_on: :desc)
  }

  def self.options_for_uncleared(options)
    raise ArgumentError, "expected Hash, got #{options.class}" unless options.is_a?(Hash)
    options = options.dup
    conditions = "statement_id IS NULL"
    parameters = []
    if options[:with]
      with_obj = options[:with]
      with_id = with_obj.is_a?(Statement) ? with_obj.id : with_obj
      conditions = "(#{conditions} OR statement_id = ?)"
      parameters << with_id
    end
    { conditions: [conditions, *parameters], include: options[:include], order: 'occurred_on DESC' }
  end

  protected

    def increment_balance
      account.update_columns(balance: account.balance + amount, updated_at: Time.current) if account
    end

    def decrement_balance
      account.update_columns(balance: account.balance - amount, updated_at: Time.current) if account
    end
end
