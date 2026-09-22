class TaggedItem < ApplicationRecord
  include OptionHandler
  include Pageable

  belongs_to :event, optional: true
  belongs_to :tag, optional: true

  before_create :ensure_consistent_tag, :increment_tag_balance, :ensure_occurred_on
  before_destroy :decrement_tag_balance

  delegate :name, to: :tag, allow_nil: true

  def tag_id=(value)
    case value
    when Integer then super(value)
    when /\A\s*\d+\s*\z/ then super(value.to_i)
    else
      @tag_to_translate = value
      # don't call super yet; will be handled in before_create
    end
  end

  def as_json(options={})
    # render json: ..., location: ... passes a frozen options hash through
    # to_json → as_json, so work on a copy.
    options = options.dup
    options[:except] = Array(options[:except]) + [:event_id, :occurred_on]
    options[:except] << :tag_id if persisted?
    append_to_options(options, :include, tag: { except: :subscription_id })
    super(options)
  end

  protected

    def ensure_consistent_tag
      if @tag_to_translate && @tag_to_translate =~ /\An:(.*)/
        self.tag_id = event.subscription.tags.find_or_create_by(name: $1).id
      else
        # make sure the given tag id exists in the given subscription
        event.subscription.tags.find(tag_id)
      end
    end

    def ensure_occurred_on
      self.occurred_on ||= event.occurred_on if event
    end

    def increment_tag_balance
      Tag.where(id: tag_id).update_all("balance = balance + #{amount.to_i}")
    end

    def decrement_tag_balance
      Tag.where(id: tag_id).update_all("balance = balance - #{amount.to_i}")
    end
end
