class AddBucketDisplaySizeForAccount < ActiveRecord::Migration[8.0]
  def up
    add_column :accounts, :bucket_display_size, :integer
  end

  def down
    remove_column :accounts, :bucket_display_size
  end
end
