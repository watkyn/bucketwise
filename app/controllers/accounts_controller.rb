class AccountsController < ApplicationController
  acceptable_includes :author, :buckets

  before_action :find_account, except: %w[index create new change_password]
  before_action :find_subscription, only: %w[index create new]

  def index
    render json: subscription.accounts.as_json(eager_options)
  end

  def show
    respond_to do |format|
      format.html do
        @page = (params[:page] || 0).to_i
        @more_pages, @items = account.account_items.page(@page)
      end
      format.json { render json: account.as_json(eager_options) }
    end
  end

  def new
    @account = Account.template
    respond_to do |format|
      format.html
      format.json { render json: @account }
    end
  end

  def create
    @account = subscription.accounts.build(account_params)
    @account.author = user
    @account.save!
    respond_to do |format|
      format.html { redirect_to subscription_path(subscription) }
      format.json { render json: @account, status: :created, location: account_url(@account) }
    end
  rescue ActiveRecord::RecordInvalid => error
    @account = error.record
    respond_to do |format|
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: @account.errors, status: :unprocessable_entity }
    end
  end

  def destroy
    account.destroy
    respond_to do |format|
      format.html { redirect_to subscription_path(subscription) }
      format.json { head :ok }
    end
  end

  def update
    account.update!(account_params)
    respond_to do |format|
      format.turbo_stream
      format.json { render json: account }
    end
  rescue ActiveRecord::RecordInvalid
    render json: account.errors, status: :unprocessable_entity
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
