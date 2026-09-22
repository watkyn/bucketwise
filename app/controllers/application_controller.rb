class ApplicationController < ActionController::Base
  include OptionHandler

  protect_from_forgery with: :exception

  before_action :authenticate

  rescue_from ActiveRecord::RecordNotFound, with: :render_404

  protected

    attr_reader :subscription, :user
    helper_method :subscription, :user

    def find_subscription
      @subscription = user.subscriptions.find(params[:subscription_id] || params[:id])
    end

    def authenticate
      if session[:user_id]
        @user = User.find(session[:user_id])
      elsif via_api?
        authenticate_or_request_with_http_basic do |user_name, password|
          @user = User.authenticate(user_name, password)
        end
      else
        redirect_to new_session_path
      end
    end

    def current_location
      controller_name
    end
    helper_method :current_location

    def render_404
      respond_to do |format|
        format.html { render file: Rails.root.join("public/404.html"), status: :not_found, layout: false }
        format.json { head :not_found }
        format.any  { head :not_found }
      end
    end

    def via_api?
      request.format.json?
    end
    helper_method :via_api?

  private

    def self.acceptable_includes(*list)
      @acceptable_includes ||= Set.new
      if list.any?
        @acceptable_includes = Set.new(list.map(&:to_s)) + @acceptable_includes
      end
      @acceptable_includes
    end

    def acceptable_includes
      self.class.acceptable_includes
    end

    def eager_options(options={})
      if params[:include]
        list = acceptable_includes & params[:include].split(/,/)
        append_to_options(options, :include, list.map(&:to_sym)) if list.any?
      end
      options
    end
end
