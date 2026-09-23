class AddLimitToAccounts < ActiveRecord::Migration[8.0]
  def up
    add_column :accounts, :limit, :integer
  end

  def down
    remove_column :accounts, :limit
  end
end
