class RemoveBucketDisplaySize < ActiveRecord::Migration
  def self.up
    remove_column :accounts, :bucket_display_size
  end

  def self.down
    add_column :accounts, :bucket_display_size, :integer
  end
end
