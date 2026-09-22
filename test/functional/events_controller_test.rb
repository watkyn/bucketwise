require 'test_helper'

class EventsControllerTest < ActionController::TestCase
  setup :login_default_user

  test "show should 404 when user without permissions requests page" do
    xhr :get, :show, :id => events(:tim_checking_starting_balance).id
    assert_response :missing
  end

  test "edit should 404 when user without permissions requests page" do
    get :edit, :id => events(:tim_checking_starting_balance).id
    assert_response :missing
  end

  test "create should 404 when user without permissions requests page" do
    assert_no_difference "Event.count" do
      xhr :post, :create, :subscription_id => subscriptions(:tim).id,
        :event => simple_event(:tim_checking, :tim_checking_general)
      assert_response :missing
    end
  end

  test "update should 404 when user without permissions requests page" do
    xhr :post, :update, :id => events(:tim_checking_starting_balance).id
    assert_response :missing
  end

  test "destroy should 404 when user without permissions requests page" do
    assert_no_difference "Event.count" do
      xhr :delete, :destroy, :id => events(:tim_checking_starting_balance).id
      assert_response :missing
    end
  end

  test "show via ajax should load subscription and event and render javascript" do
    xhr :get, :show, :id => events(:john_lunch).id
    assert_response :success
    assert_template "events/show"
    assert_equal subscriptions(:john), assigns(:subscription)
    assert_equal events(:john_lunch), assigns(:event)
  end

  test "edit should load subscription and event and render page" do
    get :edit, :id => events(:john_lunch).id
    assert_response :success
    assert_template "events/edit"
    assert_equal subscriptions(:john), assigns(:subscription)
    assert_equal events(:john_lunch), assigns(:event)
  end

  test "create via ajax should load subscription and create event and render javascript" do
    assert_difference "subscriptions(:john).events.count" do
      xhr :post, :create, :subscription_id => subscriptions(:john).id,
        :event => simple_event(:john_checking, :john_checking_household)
      assert_response :success
    end

    assert_template "events/create"
    assert_equal subscriptions(:john), assigns(:subscription)
    assert_equal "Somebody", assigns(:event).actor_name
  end

  test "create via turbo_stream should refresh lists without replacing the form" do
    assert_difference "subscriptions(:john).events.count" do
      post :create, :subscription_id => subscriptions(:john).id,
        :event => simple_event(:john_checking, :john_checking_household),
        :format => "turbo_stream"
      assert_response :success
    end

    assert_template "events/create"
    assert @response.body.include?('target="recent_entries"'), "expected recent_entries stream"
    assert @response.body.include?('target="accounts_summary"'), "expected accounts_summary stream"
    assert !@response.body.include?('target="new_event"'), "must not replace #new_event (the form lives there)"
  end

  test "create via turbo_stream with validation errors should return 422 JSON, not the success template" do
    data = simple_event(:john_checking, :john_checking_dining)
    data[:actor_name] = ""

    assert_no_difference "Event.count" do
      post :create, :subscription_id => subscriptions(:john).id, :event => data,
        :format => "turbo_stream"
      assert_response :unprocessable_entity
    end

    assert !@response.body.include?("recent_entries"), "error must not render success streams"
    assert JSON.parse(@response.body).key?("actor_name")
  end

  test "update via ajax should load subscription and event, update event and redirect back to caller" do
    event = events(:john_checking_starting_balance)
    xhr :post, :update, :id => event.id,
      :event => { :occurred_on => event.occurred_on.to_s, :actor_name => "Updated: #{event.actor_name}" }

    assert_response :redirect
    assert_redirected_to subscription_url(subscriptions(:john))
    assert_equal subscriptions(:john), assigns(:subscription)
    assert_equal events(:john_checking_starting_balance), assigns(:event)
    assert events(:john_checking_starting_balance, :reload).actor_name.starts_with?("Updated: ")
  end

  test "destroy via ajax should load subscription and event, destroy event and render javascript" do
    assert_difference "subscriptions(:john).events.count", -1 do
      xhr :delete, :destroy, :id => events(:john_lunch).id
      assert_response :success
    end

    assert_template "events/destroy"
    assert_equal subscriptions(:john), assigns(:subscription)
    assert_equal events(:john_lunch), assigns(:event)
    assert !Event.exists?(events(:john_lunch).id)
  end

  test "new should 404 when user without permission requests page" do
    get :new, :subscription_id => subscriptions(:tim).id
    assert_response :missing
  end

  test "new should 404 when user requests from bucket without access" do
    get :new, :subscription_id => subscriptions(:john).id, :role => :reallocation, :from => buckets(:tim_checking_general).id
    assert_response :missing
  end

  test "new should 404 when user requests to bucket without access" do
    get :new, :subscription_id => subscriptions(:john).id, :role => :reallocation, :to => buckets(:tim_checking_general).id
    assert_response :missing
  end

  test "new 'from reallocation' should render correct edit form" do
    get :new, :subscription_id => subscriptions(:john).id, :role => :reallocation, :from => buckets(:john_checking_general).id
    assert_response :success
    assert_template "events/new"
    assert_select "#reallocate_from"
    assert_select "#reallocate_to", false
  end

  test "new 'to reallocation' should render correct edit form" do
    get :new, :subscription_id => subscriptions(:john).id, :role => :reallocation, :to => buckets(:john_checking_general).id
    assert_response :success
    assert_template "events/new"
    assert_select "#reallocate_to"
    assert_select "#reallocate_from", false
  end

  # == API tests ========================================================================

  test "index HTML without a container should redirect to the user's root subscription" do
    login! :tim
    get :index
    assert_redirected_to subscription_url(subscriptions(:tim))
  end

  test "index JSON without a container should return an explicit 400" do
    get :index, :format => "json"
    assert_response :bad_request
    assert JSON.parse(@response.body)["error"]
  end

  test "index via API should authenticate correctly via HTTP basic authentication" do
    logout!
    api_login! :john, "testing"
    get :index, :subscription_id => subscriptions(:john).id, :format => "json"
    assert_response :success
  end

  test "index via API should return first page of recent events for subscription" do
    get :index, :subscription_id => subscriptions(:john).id, :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.any?
  end

  test "index via API should return first page of events for specified account" do
    get :index, :account_id => accounts(:john_checking).id, :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.any?
  end

  test "index via API should return first page of events for specified bucket" do
    get :index, :bucket_id => buckets(:john_checking_dining).id, :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.any?
  end

  test "index via API should return first page of events for specified tag" do
    get :index, :tag_id => tags(:john_lunch).id, :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.any?
  end

  test "index via API with page and limit should return given page of events" do
    get :index, :bucket_id => buckets(:john_checking_dining).id, :format => "json", :page => 1, :size => 2
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal [events(:john_lunch_again).id, events(:john_lunch).id],
      json.map { |event| event["id"] }
  end

  test "index via API with include should return events with line items" do
    get :index, :bucket_id => buckets(:john_checking_dining).id, :format => "json", :include => "line_items"
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.all? { |event| event["line_items"] }
  end

  test "index via API with include should return events with tagged items" do
    get :index, :bucket_id => buckets(:john_checking_dining).id, :format => "json", :include => "tagged_items"
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.all? { |event| event["tagged_items"] }
  end

  test "show via API should return requested event record" do
    get :show, :id => events(:john_lunch).id, :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal events(:john_lunch).id, json["id"]
  end

  test "new via API for reallocation should return template for reallocation" do
    get :new, :subscription_id => subscriptions(:john).id, :role => "reallocation", :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal ['primary', 'reallocate_from | reallocate_to'], json["line_items"].map { |i| i["role"] }.sort
  end

  test "new via API for expense should return template for expense" do
    get :new, :subscription_id => subscriptions(:john).id, :role => "expense", :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal ['aside', 'credit_options', 'payment_source'], json["line_items"].map { |i| i["role"] }.sort
  end

  test "new via API for deposit should return template for deposit" do
    get :new, :subscription_id => subscriptions(:john).id, :role => "deposit", :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal ['deposit'], json["line_items"].map { |i| i["role"] }.sort
  end

  test "new via API for transfer should return template for transfer" do
    get :new, :subscription_id => subscriptions(:john).id, :role => "transfer", :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert_equal ['transfer_from', 'transfer_to'], json["line_items"].map { |i| i["role"] }.sort
  end

  test "create via API with validation errors should return 422 with errors" do
    data = simple_event(:john_checking, :john_checking_dining)
    data[:actor_name] = ""

    assert_no_difference "Event.count" do
      post :create, :subscription_id => subscriptions(:john).id, :event => data, :format => "json"
      assert_response :unprocessable_entity
    end

    assert JSON.parse(@response.body).key?("actor_name")
  end

  test "create via API should return 201 and new event record" do
    assert_difference "Event.count" do
      post :create, :subscription_id => subscriptions(:john).id,
        :event => simple_event(:john_checking, :john_checking_dining), :format => "json"
      assert_response :created
    end

    json = JSON.parse(@response.body)
    assert json.key?("id")
    assert @response.headers['Location']
  end

  test "update via API with validation errors should return 422 with errors" do
    event = events(:john_checking_starting_balance)
    put :update, :id => event.id,
      :event => { :occurred_on => event.occurred_on.to_s, :actor_name => "" },
      :format => "json"
    assert_response :unprocessable_entity
    assert JSON.parse(@response.body).key?("actor_name")
  end

  test "update via API should return 200 and updated event record" do
    event = events(:john_checking_starting_balance)
    put :update, :id => event.id,
      :event => { :occurred_on => event.occurred_on.to_s, :actor_name => "Updated!" },
      :format => "json"
    assert_response :success
    json = JSON.parse(@response.body)
    assert json.key?("id")
    assert_equal "Updated!", event.reload.actor_name
  end

  test "destroy via API should destroy record and return 200" do
    assert_difference "Event.count", -1 do
      delete :destroy, :id => events(:john_lunch).id, :format => "json"
      assert_response :success
    end
  end

  private

    def simple_event(account, bucket)
      { :occurred_on => Date.today.to_s, :actor_name => "Somebody",
        :line_items => [
          { :account_id => accounts(account).id.to_s,
            :bucket_id  => buckets(bucket).id.to_s,
            :amount     => "-2000",
            :role       => "payment_source" }
          ],
          :tagged_items => [] }
    end
end
