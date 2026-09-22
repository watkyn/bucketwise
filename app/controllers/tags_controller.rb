class TagsController < ApplicationController
  before_action :find_subscription, only: %w[index new create]
  before_action :find_tag, except: %w[index new create]

  def index
    render json: subscription.tags
  end

  def show
    respond_to do |format|
      format.html do
        @page = (params[:page] || 0).to_i
        @more_pages, @items = tag_ref.tagged_items.page(@page)
      end
      format.json { render json: tag_ref }
    end
  end

  def new
    @tag = Tag.template
    render json: @tag
  end

  def create
    @tag_ref = subscription.tags.build(tag_params)
    @tag_ref.save!
    render json: @tag_ref, status: :created, location: tag_url(@tag_ref)
  rescue ActiveRecord::RecordInvalid => error
    @tag_ref = error.record
    render json: @tag_ref.errors, status: :unprocessable_entity
  end

  def update
    tag_ref.update!(tag_params)
    respond_to do |format|
      format.turbo_stream
      format.json { render json: tag_ref }
    end
  rescue ActiveRecord::RecordInvalid
    render json: tag_ref.errors, status: :unprocessable_entity
  end

  def destroy
    if params[:receiver_id].present?
      receiver = subscription.tags.find(params[:receiver_id])
      receiver.assimilate(tag_ref)
    else
      tag_ref.destroy
    end

    respond_to do |format|
      format.html { redirect_to(receiver || subscription_path(subscription)) }
      format.json { head :ok }
    end
  rescue ActiveRecord::RecordNotSaved
    head :unprocessable_entity
  end

  protected

    attr_reader :tag_ref
    helper_method :tag_ref

    def find_tag
      @tag_ref = Tag.find(params[:id])
      @subscription = user.subscriptions.find(@tag_ref.subscription_id)
    end

    def current_location
      if tag_ref && tag_ref.persisted?
        "tags/%d" % tag_ref.id
      else
        super
      end
    end

  private

    def tag_params
      params.require(:tag).permit(:name)
    rescue ActionController::ParameterMissing
      params.permit(:name)
    end
end
