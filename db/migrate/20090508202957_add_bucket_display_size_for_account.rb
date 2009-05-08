class AddBucketDisplaySizeForAccount < ActiveRecord::Migration
  def self.up
    add_column :accounts, :bucket_display_size, :integer
  end

  def self.down
    remove_column :accounts, :bucket_display_size
  end
end
