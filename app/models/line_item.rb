class LineItem < ApplicationRecord
  include Pageable

  VALID_ROLES = %w[payment_source
                   credit_options
                   transfer_to
                   transfer_from
                   deposit
                   reallocate_to
                   reallocate_from
                   aside
                   primary]

  VALID_ROLE_GROUPS = {
    "payment_source"  => %w[payment_source credit_options aside],
    "credit_options"  => %w[payment_source credit_options aside],
    "transfer_to"     => %w[transfer_from transfer_to],
    "transfer_from"   => %w[transfer_from transfer_to],
    "deposit"         => %w[deposit],
    "reallocate_to"   => %w[primary reallocate_to],
    "reallocate_from" => %w[reallocate_from primary],
    "aside"           => %w[payment_source credit_options aside]
  }

  belongs_to :event, optional: true
  belongs_to :account, optional: true
  belongs_to :bucket, optional: true

  after_create :increment_bucket_balance
  before_destroy :decrement_bucket_balance

  def as_json(options={})
    options[:except] = Array(options[:except]) + [:event_id, :occurred_on, :id]
    super(options)
  end

  protected

    def increment_bucket_balance
      bucket.update_columns(balance: bucket.balance + amount, updated_at: Time.current) if bucket
    end

    def decrement_bucket_balance
      bucket.update_columns(balance: bucket.balance - amount, updated_at: Time.current) if bucket
    end
end
