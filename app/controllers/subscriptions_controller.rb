class SubscriptionsController < ApplicationController
  before_action :find_subscription, except: :index

  def index
    respond_to do |format|
      format.html do
        if user.subscriptions.length == 1
          redirect_to subscription_path(user.subscriptions.first)
          return
        end
      end
      format.json { render json: user.subscriptions }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: subscription }
    end
  end
end
