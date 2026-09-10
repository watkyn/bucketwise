class BucketsController < ApplicationController
  acceptable_includes :author

  before_action :find_account, only: %w[index new create]
  before_action :find_bucket, except: %w[index new create]

  def index
    @filter = QueryFilter.new(params.permit(:from, :to, :expenses, :deposits, :reallocations).to_h)
    @buckets = account.buckets.filtered(@filter)

    respond_to do |format|
      format.html
      format.json { render json: @buckets.as_json(eager_options) }
      format.xml { render xml: @buckets.to_xml(eager_options(root: "buckets")) }
    end
  end

  def show
    respond_to do |format|
      format.html do
        @page = (params[:page] || 0).to_i
        @more_pages, @items = bucket.line_items.page(@page)
      end
      format.json { render json: bucket.as_json(eager_options) }
      format.xml { render xml: bucket.to_xml(eager_options) }
    end
  end

  def new
    @bucket = Bucket.template
    respond_to do |format|
      format.json { render json: @bucket }
      format.xml { render xml: @bucket.to_xml }
    end
  end

  def create
    respond_to do |format|
      format.json do
        @bucket = account.buckets.build(bucket_params)
        @bucket.author = user
        @bucket.save!
        render json: @bucket, status: :created, location: bucket_url(@bucket)
      end
      format.xml do
        @bucket = account.buckets.build(bucket_params)
        @bucket.author = user
        @bucket.save!
        render xml: @bucket.to_xml, status: :created, location: bucket_url(@bucket)
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    @bucket = error.record
    respond_to do |format|
      format.json { render json: @bucket.errors, status: :unprocessable_entity }
      format.xml { render xml: @bucket.errors.to_xml, status: :unprocessable_entity }
    end
  end

  def update
    bucket.update!(bucket_params)
    respond_to do |format|
      format.js
      format.json { render json: bucket }
      format.xml { render xml: bucket.to_xml }
    end
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.js { render status: :unprocessable_entity }
      format.json { render json: bucket.errors, status: :unprocessable_entity }
      format.xml { render xml: bucket.errors.to_xml, status: :unprocessable_entity }
    end
  end

  def destroy
    receiver = account.buckets.find(params[:receiver_id])
    receiver.assimilate(bucket)
    respond_to do |format|
      format.html { redirect_to receiver }
      format.json { head :ok }
      format.xml  { head :ok }
    end
  end

  protected

    attr_reader :account, :bucket, :buckets, :filter
    helper_method :account, :bucket, :buckets, :filter

    def find_account
      @account = Account.find(params[:account_id])
      @subscription = user.subscriptions.find(@account.subscription_id)
    end

    def find_bucket
      @bucket = Bucket.find(params[:id])
      @account = @bucket.account
      @subscription = user.subscriptions.find(@account.subscription_id)
    end

    def current_location
      if @bucket && @bucket.persisted?
        "buckets/%d" % @bucket.id
      else
        super
      end
    end

  private

    def bucket_params
      params.require(:bucket).permit(:name, :role)
    rescue ActionController::ParameterMissing
      params.permit(:name, :role)
    end
end
