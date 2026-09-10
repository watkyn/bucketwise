class Statement < ApplicationRecord
  belongs_to :account, optional: true
  has_many :account_items, extend: CategorizedItems, dependent: :nullify

  before_create :initialize_starting_balance
  after_save :associate_account_items_with_self

  scope :pending, -> { where(balanced_at: nil) }
  scope :balanced, -> { where.not(balanced_at: nil) }

  validates :occurred_on, presence: true
  validates :ending_balance, presence: true

  def ending_balance=(amount)
    if amount.is_a?(Float) || (amount.is_a?(String) && amount =~ /[.,]/)
      amount = (amount.to_s.tr(",", "").to_f * 100).round
    end
    super(amount)
  end

  def balance
    ending_balance
  end

  def balanced?(reload=false)
    unsettled_balance(reload).zero?
  end

  def settled_balance(reload=false)
    @settled_balance = nil if reload
    @settled_balance ||= account_items.to_a.sum(&:amount)
  end

  def unsettled_balance(reload=false)
    @unsettled_balance = nil if reload
    @unsettled_balance ||= starting_balance.to_i + settled_balance(reload) - ending_balance.to_i
  end

  def cleared=(ids)
    @ids_to_clear = ids
    @already_updated = false
  end

  protected

    def initialize_starting_balance
      self.starting_balance ||= account.statements.balanced.order(:occurred_on).last&.ending_balance || 0
    end

    def associate_account_items_with_self
      return if @already_updated
      @already_updated = true

      account_items.clear

      ids = Array(@ids_to_clear).map(&:to_i)
      if ids.any?
        AccountItem.where(account_id: account_id, id: ids).update_all(statement_id: id)
      end

      # Reset association cache
      account_items.reset if account_items.loaded?

      if @ids_to_clear
        if balanced?(true) && !balanced_at
          update_column(:balanced_at, Time.current)
        elsif !balanced? && balanced_at
          update_column(:balanced_at, nil)
        end
      end
    end

  private

    def ids_to_clear
      @ids_to_clear || []
    end
end
