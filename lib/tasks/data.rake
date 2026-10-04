namespace :data do
  namespace :subscription do
    desc "Dump all data for a single subscription (ID env var, optional FILE env var)"
    task :dump => :environment do
      id = ENV['ID'] or abort "please specify the subscription id via the ID env var"
      subscription = Subscription.find(id)

      user_ids = (
        [subscription.owner_id] +
        subscription.user_subscriptions.pluck(:user_id) +
        subscription.accounts.pluck(:user_id) +
        Bucket.where(account_id: subscription.accounts.select(:id)).pluck(:user_id) +
        subscription.events.pluck(:user_id)
      ).compact.uniq

      data = {}

      data[:users] = User.where(id: user_ids).map(&:attributes)
      data[:tags] = subscription.tags.map(&:attributes)
      data[:accounts] = subscription.accounts.map(&:attributes)
      data[:actors] = subscription.actors.map(&:attributes)
      data[:events] = subscription.events.map(&:attributes)
      data[:user_subscriptions] = subscription.user_subscriptions.map(&:attributes)

      data[:statements] = subscription.accounts.map(&:statements).flatten.map(&:attributes)
      data[:buckets] = subscription.accounts.map(&:buckets).flatten.map(&:attributes)
      data[:line_items] = subscription.events.map(&:line_items).flatten.map(&:attributes)
      data[:account_items] = subscription.events.map(&:account_items).flatten.map(&:attributes)
      data[:tagged_items] = subscription.events.map(&:tagged_items).flatten.map(&:attributes)

      data[:subscription] = subscription.attributes

      file = ENV['FILE'].presence || "#{id}.yml"
      File.open(file, "w") { |f| f.write(data.to_yaml) }
      puts "dumped subscription ##{id} to #{file}"
    end

    desc "Restores data for the given subscription file (FILE env var, CONFIRM=1 to proceed)"
    task :load => :environment do
      abort "please confirm (via the CONFIRM env var) that you really want to do this" unless ENV['CONFIRM']

      file = ENV['FILE'] or abort "please specify the dump file via the FILE env var"
      data = YAML.unsafe_load_file(file)

      fetch = lambda do |key|
        Array(data[key] || data[key.to_s])
      end
      subscription_attrs = data[:subscription] || data["subscription"] or
        abort "dump file #{file} contains no subscription"

      insert = Proc.new do |table, record|
        c = ActiveRecord::Base.connection
        columns = record.keys.map { |name| c.quote_column_name(name) }
        values = record.values.map { |value| c.quote(value) }
        c.insert("INSERT INTO #{table} (#{columns.join(",")}) VALUES (#{values.join(",")})")
      end

      Subscription.transaction do
        (data[:users] || data["users"] || []).each do |record|
          existing = User.find_by(id: record["id"] || record[:id])
          if existing
            if existing.user_name != (record["user_name"] || record[:user_name])
              abort "user ##{existing.id} (#{existing.user_name}) collides with " \
                "dump user #{record["user_name"] || record[:user_name]}; " \
                "load into a fresh database instead"
            end
          else
            insert.call("users", record)
          end
        end

        subscription = Subscription.find_by(id: subscription_attrs['id'] || subscription_attrs[:id])
        subscription.destroy if subscription

        insert.call("subscriptions", subscription_attrs)
        %i(tags accounts actors events user_subscriptions statements buckets line_items account_items tagged_items).each do |table|
          fetch.call(table).each do |record|
            insert.call(table.to_s, record)
          end
        end
      end

      puts "loaded subscription ##{subscription_attrs['id'] || subscription_attrs[:id]} from #{file}"
    end
  end
end
