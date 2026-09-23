class AddMemoFieldToEvent < ActiveRecord::Migration[8.0]
  def up
    add_column :events, :memo, :text
  end

  def down
    remove_column :events, :memo
  end
end
