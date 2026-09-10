class Actor < ApplicationRecord
  belongs_to :subscription
  has_many :events

  validates :name, presence: true
  validates :sort_name, presence: true

  def self.normalize_name(name)
    name.strip.upcase
  end

  def self.normalize(name)
    # Legacy entry point - tries to find globally then create.
    # For proper subscription-scoped lookup, use normalize_for(subscription, name)
    name = name.strip
    sort_name = normalize_name(name)

    actor = find_by(sort_name: sort_name)
    if actor
      actor.ping!
      return actor
    end

    create(sort_name: sort_name, name: name)
  end

  def self.normalize_for(subscription, name)
    name = name.strip
    sort_name = normalize_name(name)

    actor = subscription.actors.find_by(sort_name: sort_name)
    if actor
      actor.ping!
      return actor
    end

    subscription.actors.create(sort_name: sort_name, name: name)
  end

  def ping
    self.updated_at = Time.current
  end

  def ping!
    ping
    save!
  end
end
