class AccountsController < ApplicationController
  acceptable_includes :author, :buckets

  before_action :find_account, except: %w[index create new change_password]
  before_action :find_subscription, only: %w[index create new]

  def index
    respond_to do |format|
      format.json { render json: subscription.accounts.as_json(eager_options) }
      format.xml { render xml: subscription.accounts.to_xml(eager_options(root: "accounts")) }
    end
  end

  def show
    respond_to do |format|
      format.html do
        @page = (params[:page] || 0).to_i
        @more_pages, @items = account.account_items.page(@page)
      end
      format.json { render json: account.as_json(eager_options) }
      format.xml { render xml: account.to_xml(eager_options) }
    end
  end

  def new
    @account = Account.template
    respond_to do |format|
      format.html
      format.json { render json: @account }
      format.xml { render xml: @account.to_xml }
    end
  end

  def create
    @account = subscription.accounts.build(account_params)
    @account.author = user
    @account.save!
    respond_to do |format|
      format.html { redirect_to subscription_path(subscription) }
      format.json { render json: @account, status: :created, location: account_url(@account) }
      format.xml  { render xml: @account.to_xml, status: :created, location: account_url(@account) }
    end
  rescue ActiveRecord::RecordInvalid => error
    @account = error.record
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: @account.errors, status: :unprocessable_entity }
      format.xml  { render xml: @account.errors.to_xml, status: :unprocessable_entity }
    end
  end

  def destroy
    account.destroy
    respond_to do |format|
      format.html { redirect_to subscription_path(subscription) }
      format.json { head :ok }
      format.xml  { head :ok }
    end
  end

  def update
    account.update!(account_params)
    respond_to do |format|
      format.js
      format.turbo_stream
      format.json { render json: account }
      format.xml { render xml: account.to_xml }
    end
  rescue ActiveRecord::RecordInvalid
    respond_to do |format|
      format.js { render status: :unprocessable_entity }
      format.json { render json: account.errors, status: :unprocessable_entity }
      format.xml { render xml: account.errors.to_xml, status: :unprocessable_entity }
    end
  end

  def change_password
    if params[:new_password].present?
      user.password = params[:new_password]
      user.password_confirmation = params[:new_password]
      user.save!
      redirect_to root_path
    end
  end

  protected

    attr_reader :account
    helper_method :account

    def find_account
      @account = Account.find(params[:id])
      @subscription = user.subscriptions.find(@account.subscription_id)
    end

    def current_location
      if @account && @account.persisted?
        "accounts/%d" % @account.id
      else
        super
      end
    end

  private

    def account_params
      params.require(:account).permit(:name, :role, :limit, :starting_balance, starting_balance: [:amount, :occurred_on])
    rescue ActionController::ParameterMissing
      params.permit(:name, :role, :limit, :starting_balance, starting_balance: [:amount, :occurred_on])
    end
end
