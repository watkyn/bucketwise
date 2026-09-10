ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rails/test_help"

# Legacy compatibility shim for Rails 2.3 style controller tests
module LegacyControllerTestHelpers
  def get(action, *args, **kwargs)
    super(action, **normalize_legacy_args(args, kwargs))
  end

  def post(action, *args, **kwargs)
    super(action, **normalize_legacy_args(args, kwargs))
  end

  def put(action, *args, **kwargs)
    super(action, **normalize_legacy_args(args, kwargs))
  end

  def patch(action, *args, **kwargs)
    super(action, **normalize_legacy_args(args, kwargs))
  end

  def delete(action, *args, **kwargs)
    super(action, **normalize_legacy_args(args, kwargs))
  end

  # Old xhr :put, :update, :id => 1
  def xhr(verb, action, *args, **kwargs)
    # Merge positional hash if present
    if args.first.is_a?(Hash)
      kwargs = args.first.merge(kwargs)
    end
    normalized = normalize_legacy_kwargs(kwargs)
    normalized[:as] ||= :turbo_stream
    normalized[:xhr] = true
    send(verb, action, **normalized)
  end

  private

  def normalize_legacy_args(args, kwargs)
    # Handle positional hash: post :create, { :a => 1 }
    if args.first.is_a?(Hash)
      kwargs = args.first.merge(kwargs)
    elsif args.any?
      # Unexpected positional, merge
      kwargs = args.each_with_object({}) { |h, m| m.merge!(h) if h.is_a?(Hash) }.merge(kwargs)
    end
    normalize_legacy_kwargs(kwargs)
  end

  def normalize_legacy_kwargs(kwargs)
    return kwargs if kwargs.key?(:params) || kwargs.key?('params')
    known_keys = [:params, :headers, :env, :xhr, :as, :body, :session, :flash]
    params = {}
    remaining = {}
    kwargs.each do |k, v|
      if known_keys.include?(k)
        remaining[k] = v
      else
        params[k] = v
      end
    end
    remaining[:params] = params if params.any?
    remaining
  end
end

# Patch assert_response to handle :missing -> :not_found
module LegacyAssertResponse
  def assert_response(type, *args, **kwargs)
    type = :not_found if type == :missing
    super(type, *args, **kwargs)
  end
end

class ActionController::TestCase
  prepend LegacyControllerTestHelpers
  prepend LegacyAssertResponse
end

class ActiveSupport::TestCase
  fixtures :all

  protected

    def login_default_user
      login! :john
    end

  private

    def login!(who)
      @user = Symbol === who ? users(who) : who
      @request.session[:user_id] = @user.id
    end

    def logout!
      @request.session[:user_id] = nil
    end

    def api_login!(who, password)
      logout!
      @user = Symbol === who ? users(who) : who
      token = Base64.strict_encode64("#{@user.user_name}:#{password}")
      @request.env['HTTP_AUTHORIZATION'] = "Basic #{token}"
    end
end
