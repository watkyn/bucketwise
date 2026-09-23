class RemoveBucketDisplaySize < ActiveRecord::Migration[8.0]
  def up
    remove_column :accounts, :bucket_display_size
  end

  def down
    add_column :accounts, :bucket_display_size, :integer
  end
end
