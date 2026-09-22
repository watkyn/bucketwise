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
      format.turbo_stream do
        json = events.as_json(eager_options(include: { tagged_items: { only: [:amount, :id], methods: :name }, line_items: { only: [:account_id, :bucket_id, :amount, :role] } }))
        render json: json
      end
    end
  end

  def show
    respond_to do |format|
      format.turbo_stream
      format.json { render json: event.as_json(eager_options) }
    end
  end

  def edit
  end

  def new
    @event = subscription.events.prepare(params.permit(:role, :from, :to).to_h.symbolize_keys)

    respond_to do |format|
      format.html
      format.json do
        @event.build_template_line_items
        render json: @event.as_json(include: [:line_items, :tagged_items])
      end
    end
  end

  def create
    @event = subscription.events.build(event_params)
    @event.user = user
    @event.save!
    respond_to do |format|
      format.turbo_stream
      format.json { render json: @event.as_json(include: [:line_items, :tagged_items]), status: :created, location: event_url(@event) }
    end
  rescue ActiveRecord::RecordInvalid => error
    @event = error.record
    respond_to do |format|
      # Don't render the success turbo-stream template here: the client parses
      # the JSON errors and alerts them (see events-form#submit).
      format.turbo_stream { render json: @event.errors, status: :unprocessable_entity }
      format.json { render json: @event.errors, status: :unprocessable_entity }
    end
  end

  def update
    event.update!(event_params)
    respond_to do |format|
      format.turbo_stream { redirect_to(params[:return_to] || subscription_path(subscription)) }
      format.json { render json: event.as_json(include: [:line_items, :tagged_items]) }
    end
  rescue ActiveRecord::RecordInvalid => error
    respond_to do |format|
      format.turbo_stream { render json: event.errors, status: :unprocessable_entity }
      format.json { render json: event.errors, status: :unprocessable_entity }
    end
  end

  def destroy
    event.destroy
    respond_to do |format|
      format.turbo_stream
      format.json { head :ok }
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
      elsif request.format.html?
        # Bare GET /events (no container). Intended behavior: HTML requests
        # from a logged-in user redirect to their root subscription dashboard
        # (nicer than a 404/500 for this entry point); API requests get an
        # explicit 400 since a container is required to list events.
        root = user.subscriptions.first
        redirect_to root ? subscription_path(root) : subscriptions_path
      else
        render json: { error: "no container specified for event listing" }, status: :bad_request
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
      line_item_keys = [:account_id, :bucket_id, :amount, :role]
      tagged_item_keys = [:tag_id, :amount]
      permitted = params.require(:event).permit(:occurred_on, :actor_name, :check_number, :memo, :role,
        line_items: line_item_keys,
        tagged_items: tagged_item_keys,
        line_item: line_item_keys,
        tagged_item: tagged_item_keys).to_h.with_indifferent_access
      # Normalize legacy singular keys (old Rails 2 XML: line_item/tagged_item) to plural
      permitted[:line_items] ||= permitted.delete(:line_item) if permitted[:line_item]
      permitted[:tagged_items] ||= permitted.delete(:tagged_item) if permitted[:tagged_item]
      permitted.slice(:occurred_on, :actor_name, :check_number, :memo, :role, :line_items, :tagged_items)
    rescue ActionController::ParameterMissing
      {}
    end
end
