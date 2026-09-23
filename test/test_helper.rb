ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rails/test_help"

# Integration-test auth helpers. Fizzy-style: sign in through the real session
# endpoint and let the request carry the cookie, instead of poking
# @request.session directly (which integration tests do not expose).
module SessionHelpers
  # Signs in as a user fixture (or a User) and returns the user. Deliberately
  # performs no assertions so callers can also exercise failed logins.
  def sign_in(who, password: "testing")
    user = resolve_user(who)
    post session_path, params: { user_name: user.user_name, password: password }
    user
  end

  def sign_out
    delete session_path
  end

  # Authorization header for the JSON API's HTTP basic authentication.
  def basic_auth_headers(who, password: "testing")
    user = resolve_user(who)
    { "HTTP_AUTHORIZATION" => "Basic #{Base64.strict_encode64("#{user.user_name}:#{password}")}" }
  end

  private

    def resolve_user(who)
      Symbol === who ? users(who) : who
    end
end

class ActionDispatch::IntegrationTest
  include SessionHelpers
end

class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors, threshold: 10)
  fixtures :all
end
