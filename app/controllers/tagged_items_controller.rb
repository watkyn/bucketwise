class TaggedItemsController < ApplicationController
  before_action :find_event, only: :create
  before_action :find_tagged_item, only: :destroy

  def create
    @tagged_item = event.tagged_items.build(tagged_item_params)
    @tagged_item.save!
    render json: @tagged_item, status: :created, location: tagged_item_url(@tagged_item)
  rescue ActiveRecord::RecordInvalid => error
    @tagged_item = error.record
    render json: @tagged_item.errors, status: :unprocessable_entity
  end

  def destroy
    tagged_item.destroy
    head :ok
  end

  protected

    attr_reader :event, :tagged_item
    helper_method :event, :tagged_item

    def find_event
      @event = Event.find(params[:event_id])
      @subscription = user.subscriptions.find(@event.subscription_id)
    end

    def find_tagged_item
      @tagged_item = TaggedItem.find(params[:id])
      @event = @tagged_item.event
      @subscription = user.subscriptions.find(@event.subscription_id)
    end

  private

    def tagged_item_params
      params.require(:tagged_item).permit(:tag_id, :amount, :tag)
    rescue ActionController::ParameterMissing
      params.permit(:tag_id, :amount, :tag)
    end
end
