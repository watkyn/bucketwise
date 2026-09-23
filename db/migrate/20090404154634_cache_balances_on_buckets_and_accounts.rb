class CacheBalancesOnBucketsAndAccounts < ActiveRecord::Migration[8.0]
  def up
    add_column :accounts, :balance, :integer, :null => false, :default => 0
    add_column :buckets, :balance, :integer, :null => false, :default => 0

    execute <<~SQL
      UPDATE accounts
      SET balance = COALESCE((
        SELECT SUM(account_items.amount)
        FROM account_items
        WHERE account_items.account_id = accounts.id
      ), 0)
    SQL

    execute <<~SQL
      UPDATE buckets
      SET balance = COALESCE((
        SELECT SUM(line_items.amount)
        FROM line_items
        WHERE line_items.bucket_id = buckets.id
      ), 0)
    SQL
  end

  def down
    remove_column :accounts, :balance, :integer
    remove_column :buckets, :balance, :integer
  end
end
