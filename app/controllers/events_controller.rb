class EventsController < ApplicationController
  acceptable_includes :line_items, :user, :tagged_items

  before_action :find_container, :find_events, only: :index
  before_action :find_subscription, only: %w[new create]
  before_action :find_event, except: %w[index new create]

  def index
    respond_to do |format|
      format.json do
        render json: events.as_json(eager_options(include: { tagged_items: { only: [:amount, :id], methods: :name }, line_items: { only: [:account_id, :bucket_id, :amount, :role] } }))
      end
      format.js do
        # Legacy RJS support: return JSON for doneLoadingRecalledEvents
        json = events.to_json(eager_options(include: { tagged_items: { only: [:amount, :id], methods: :name }, line_items: { only: [:account_id, :bucket_id, :amount, :role] } }))
        render js: "Events.doneLoadingRecalledEvents(#{json})"
      end
      format.xml do
        render xml: events.to_xml(eager_options(root: "events"))
      end
    end
  end

  def show
    respond_to do |format|
      format.js
      format.json { render json: event.as_json(eager_options) }
      format.xml { render xml: event.to_xml(eager_options) }
    end
  end

  def edit
  end

  def new
    @event = subscription.events.prepare(params.permit(:role, :from, :to).to_h.symbolize_keys)

    respond_to do |format|
      format.html
      format.json { render json: @event.as_json(include: [:line_items, :tagged_items]) }
      format.xml { render xml: @event.to_xml(include: [:line_items, :tagged_items]) }
    end
  end

  def create
    @event = subscription.events.build(event_params)
    @event.user = user
    @event.save!
    respond_to do |format|
      format.js
      format.json { render json: @event.as_json(include: [:line_items, :tagged_items]), status: :created, location: event_url(@event) }
      format.xml do
        render xml: @event.to_xml(include: [:line_items, :tagged_items]), status: :created, location: event_url(@event)
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    @event = error.record
    respond_to do |format|
      format.js { render status: :unprocessable_entity }
      format.json { render json: @event.errors, status: :unprocessable_entity }
      format.xml { render xml: @event.errors, status: :unprocessable_entity }
    end
  end

  def update
    event.update!(event_params)
    respond_to do |format|
      format.js
      format.json { render json: event.as_json(include: [:line_items, :tagged_items]) }
      format.xml { render xml: event.to_xml(include: [:line_items, :tagged_items]) }
    end
  rescue ActiveRecord::RecordInvalid => error
    respond_to do |format|
      format.js { render status: :unprocessable_entity }
      format.json { render json: event.errors, status: :unprocessable_entity }
      format.xml { render xml: event.errors, status: :unprocessable_entity }
    end
  end

  def destroy
    event.destroy
    respond_to do |format|
      format.js
      format.json { head :ok }
      format.xml { head :ok }
    end
  end

  protected

    attr_reader :event, :container, :account, :bucket, :tag, :events
    helper_method :event, :container, :account, :bucket

    def find_event
      @event = Event.find(params[:id])
      @subscription = user.subscriptions.find(@event.subscription_id)
    end

    def find_container
      if params[:subscription_id]
        @container = find_subscription
      elsif params[:account_id]
        @container = @account = Account.find(params[:account_id])
        @subscription = user.subscriptions.find(@account.subscription_id)
      elsif params[:bucket_id]
        @container = @bucket = Bucket.find(params[:bucket_id])
        @subscription = user.subscriptions.find(@bucket.account.subscription_id)
      elsif params[:tag_id]
        @container = @tag = Tag.find(params[:tag_id])
        @subscription = user.subscriptions.find(@tag.subscription_id)
      else
        raise ArgumentError, "no container specified for event listing"
      end
    end

    def find_events
      method = :page

      case container
      when Subscription
        association = :events
        method = :recent
      when Account
        association = :account_items
      when Bucket
        association = :line_items
      when Tag
        association = :tagged_items
      else
        raise ArgumentError, "unsupported container type #{container.class}"
      end

      more_pages, list = container.send(association).send(method, params[:page], size: params[:size], actor: params[:actor])
      unless list.first.is_a?(Event)
        list = list.map do |item|
          ev = item.event
          ev.amount = item.amount
          ev
        end
      end

      @events = list
    end

  private

    def event_params
      params.require(:event).permit(:occurred_on, :actor_name, :check_number, :memo, :role,
        line_items: [:account_id, :bucket_id, :amount, :role],
        tagged_items: [:tag_id, :amount])
    rescue ActionController::ParameterMissing
      # For API callers using raw hash (tests may send event as hash without wrapper)
      # Permit differently: try to allow line_items as array of hashes
      permitted = params.permit(:occurred_on, :actor_name, :check_number, :memo, :role, :subscription_id,
        event: [:occurred_on, :actor_name, :check_number, :memo, :role, line_items: [:account_id, :bucket_id, :amount, :role], tagged_items: [:tag_id, :amount]])
      if permitted[:event]
        ev = permitted[:event]
        # Handle line_items as array
        if params[:event] && params[:event][:line_items]
          ev[:line_items] = params[:event][:line_items].map { |li| li.permit(:account_id, :bucket_id, :amount, :role).to_h } rescue params[:event][:line_items]
        end
        if params[:event] && params[:event][:tagged_items]
          ev[:tagged_items] = params[:event][:tagged_items].map { |ti| ti.permit(:tag_id, :amount).to_h } rescue params[:event][:tagged_items]
        end
        ev
      else
        # fallback to raw event hash
        raw = params[:event] || params
        raw.permit! if raw.respond_to?(:permit!)
        raw.to_h
      end
    end
end
