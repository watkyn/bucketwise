class NormalizeActors < ActiveRecord::Migration[8.0]
  class EventRecord < ActiveRecord::Base
    self.table_name = "events"
  end

  class ActorRecord < ActiveRecord::Base
    self.table_name = "actors"
  end

  def up
    rename_column :events, :actor, :actor_name
    add_column :events, :actor_id, :integer
    add_index :events, :actor_id

    create_table :actors do |t|
      t.integer :subscription_id, :null => false
      t.string  :name, :null => false
      t.string  :sort_name, :null => false
      t.timestamps :null => true
    end

    add_index :actors, %w(subscription_id sort_name), :unique => true
    add_index :actors, %w(subscription_id updated_at)

    EventRecord.reset_column_information
    ActorRecord.reset_column_information

    say_with_time "normalizing all existing event actors" do
      EventRecord.find_each do |event|
        name = event.actor_name.to_s.strip
        sort_name = name.upcase
        actor = ActorRecord.find_or_create_by!(subscription_id: event.subscription_id, sort_name: sort_name) do |record|
          record.name = name
        end
        event.update_column(:actor_id, actor.id)
      end
    end
  end

  def down
    drop_table :actors

    remove_index :events, :actor_id
    remove_column :events, :actor_id
    rename_column :events, :actor_name, :actor
  end
end
