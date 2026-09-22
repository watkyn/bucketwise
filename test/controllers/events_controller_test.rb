require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  test "show should 404 when user without permissions requests page" do
    get event_path(events(:tim_checking_starting_balance)), as: :turbo_stream

    assert_response :not_found
  end

  test "edit should 404 when user without permissions requests page" do
    get edit_event_path(events(:tim_checking_starting_balance))

    assert_response :not_found
  end

  test "create should 404 when user without permissions requests page" do
    assert_no_difference -> { Event.count } do
      post subscription_events_path(subscriptions(:tim)),
        params: { event: simple_event(:tim_checking, :tim_checking_general) },
        as: :turbo_stream
      assert_response :not_found
    end
  end

  test "update should 404 when user without permissions requests page" do
    put event_path(events(:tim_checking_starting_balance)), as: :turbo_stream

    assert_response :not_found
  end

  test "destroy should 404 when user without permissions requests page" do
    assert_no_difference -> { Event.count } do
      delete event_path(events(:tim_checking_starting_balance)), as: :turbo_stream
      assert_response :not_found
    end
  end

  test "show via turbo_stream should load subscription and event and render the expand stream" do
    event = events(:john_lunch)

    get event_path(event), as: :turbo_stream

    # Getting a 200 here (instead of the before_action's 404) is what proves the
    # subscription was resolved for the signed-in user: an event belonging to
    # another user's subscription never reaches this action.
    assert_response :ok
    assert_includes @response.body, %(<turbo-stream action="after" target="event_#{event.id}">),
      "expected the show template to expand the event's row"
    assert_includes @response.body, %(id="zoomed_event_#{event.id}"),
      "expected the expanded detail row for the requested event"
    assert_includes @response.body, %(<a href="#{account_path(accounts(:john_checking))}">Checking</a>),
      "expected the event's line items to render with their account links"
  end

  test "show via turbo_stream should render tag links as real links, not escaped HTML" do
    get event_path(events(:john_lunch)), as: :turbo_stream
    assert_response :ok

    assert_includes @response.body,
      %(<a href="#{tag_path(tags(:john_lunch))}">lunch</a>),
      "expected a real tag link in the expanded event"
    assert_includes @response.body,
      %(<a href="#{tag_path(tags(:john_tip))}">tip</a>),
      "expected a real tag link in the expanded event"
    refute_includes @response.body, "&lt;a href=",
      "expected real <a> elements in the expanded event, found escaped HTML instead"
  end

  test "show via turbo_stream should insert expanded row after event row" do
    event = events(:john_lunch)

    get event_path(event), as: :turbo_stream
    assert_response :ok

    assert_includes @response.body,
      %(<turbo-stream action="after" target="event_#{event.id}">),
      "expected expand stream to insert after the event row (replace on zoomed_event_* targets a row that does not exist yet, so the info button does nothing)"
    assert_includes @response.body, %(id="zoomed_event_#{event.id}"),
      "expected expanded detail row in the stream"
    refute_includes @response.body, "<script>",
      "Turbo strips <script> tags, so class toggling must live in event-row#expand, not inline JS"
  end

  test "edit should load subscription and event and render page" do
    event = events(:john_lunch)

    get edit_event_path(event)

    assert_response :ok
    assert_select "form#event_form[action=?]", event_path(event)
    assert_select "input[name=?]", "event[actor_name]"
    assert_select "div.transaction[data-events-form-return-to-value=?]",
      subscription_path(subscriptions(:john))
  end

  test "create via turbo_stream should load subscription and create event and render the create template" do
    assert_difference -> { subscriptions(:john).events.count }, 1 do
      post subscription_events_path(subscriptions(:john)),
        params: { event: simple_event(:john_checking, :john_checking_household) },
        as: :turbo_stream
      assert_response :ok
    end

    created = Event.last
    assert_equal "Somebody", created.actor_name
    assert_equal subscriptions(:john), created.subscription
    assert_includes @response.body, %(<turbo-stream action="replace" target="recent_entries">),
      "expected the create template to refresh the recent entries list"
  end

  test "create via turbo_stream should refresh lists without replacing the form" do
    assert_difference -> { subscriptions(:john).events.count }, 1 do
      post subscription_events_path(subscriptions(:john)),
        params: { event: simple_event(:john_checking, :john_checking_household) },
        as: :turbo_stream
      assert_response :ok
    end

    assert_includes @response.body, %(target="recent_entries"), "expected recent_entries stream"
    assert_includes @response.body, %(target="accounts_summary"), "expected accounts_summary stream"
    refute_includes @response.body, %(target="new_event"),
      "must not replace #new_event (the form lives there)"
  end

  test "create via turbo_stream with validation errors should return 422 JSON, not the success template" do
    data = simple_event(:john_checking, :john_checking_dining)
    data[:actor_name] = ""

    assert_no_difference -> { Event.count } do
      post subscription_events_path(subscriptions(:john)), params: { event: data }, as: :turbo_stream
      assert_response :unprocessable_entity
    end

    refute_includes @response.body, "recent_entries", "error must not render success streams"
    assert JSON.parse(@response.body).key?("actor_name")
  end

  test "update via turbo_stream should load subscription and event, update event and redirect back to caller" do
    event = events(:john_checking_starting_balance)

    put event_path(event), params: {
      event: { occurred_on: event.occurred_on.to_s, actor_name: "Updated: #{event.actor_name}" }
    }, as: :turbo_stream

    assert_redirected_to subscription_url(subscriptions(:john))
    assert event.reload.actor_name.start_with?("Updated: ")
  end

  test "destroy via turbo_stream should load subscription and event, destroy event and render streams" do
    event = events(:john_lunch)

    assert_difference -> { subscriptions(:john).events.count }, -1 do
      delete event_path(event), as: :turbo_stream
      assert_response :ok
    end

    assert_not Event.exists?(event.id)
    assert_includes @response.body, %(<turbo-stream action="remove" target="event_#{event.id}">),
      "expected the destroy template to remove the event's row"
    assert_includes @response.body, %(<a href="#{account_path(accounts(:john_checking))}">Checking</a>),
      "expected the refreshed accounts summary to render this subscription's accounts"
  end

  test "destroy from subscription page should remove row and refresh accounts summary" do
    event = events(:john_lunch)

    delete event_path(event), params: { from: "subscriptions" }, as: :turbo_stream

    assert_response :ok
    assert_not Event.exists?(event.id)

    assert_includes @response.body, %(<turbo-stream action="remove" target="event_#{event.id}">)
    assert_includes @response.body, %(<turbo-stream action="replace" target="accounts_summary">)
  end

  test "destroy from account page should remove row and refresh balance" do
    event = events(:john_lunch)
    account = accounts(:john_checking)

    delete event_path(event), params: { from: "accounts/#{account.id}" }, as: :turbo_stream

    assert_response :ok
    assert_not Event.exists?(event.id)

    assert_includes @response.body, %(<turbo-stream action="remove" target="event_#{event.id}">)
    assert_includes @response.body, %(<turbo-stream action="replace" target="balance">),
      "expected a balance refresh when deleting from an account page"
  end

  test "destroy from bucket page should remove row and refresh balance" do
    event = events(:john_lunch)
    bucket = buckets(:john_checking_dining)

    delete event_path(event), params: { from: "buckets/#{bucket.id}" }, as: :turbo_stream

    assert_response :ok
    assert_not Event.exists?(event.id)

    assert_includes @response.body, %(<turbo-stream action="remove" target="event_#{event.id}">)
    assert_includes @response.body, %(<turbo-stream action="replace" target="balance">),
      "expected a balance refresh when deleting from a bucket page"
  end

  test "destroy from tag page should remove row and refresh balance" do
    event = events(:john_lunch)
    tag = tags(:john_lunch)

    delete event_path(event), params: { from: "tags/#{tag.id}" }, as: :turbo_stream

    assert_response :ok
    assert_not Event.exists?(event.id)

    assert_includes @response.body, %(<turbo-stream action="remove" target="event_#{event.id}">)
    assert_includes @response.body, %(<turbo-stream action="replace" target="balance">),
      "expected a balance refresh when deleting from a tag page"
  end

  test "new should 404 when user without permission requests page" do
    get new_subscription_event_path(subscriptions(:tim))

    assert_response :not_found
  end

  test "new should 404 when user requests from bucket without access" do
    get new_subscription_event_path(subscriptions(:john)),
      params: { role: :reallocation, from: buckets(:tim_checking_general).id }

    assert_response :not_found
  end

  test "new should 404 when user requests to bucket without access" do
    get new_subscription_event_path(subscriptions(:john)),
      params: { role: :reallocation, to: buckets(:tim_checking_general).id }

    assert_response :not_found
  end

  test "new 'from reallocation' should render correct edit form" do
    get new_subscription_event_path(subscriptions(:john)),
      params: { role: :reallocation, from: buckets(:john_checking_general).id }

    assert_response :ok
    assert_select "form#event_form[action=?]",
      subscription_events_path(subscriptions(:john), source: "new")
    assert_select "#reallocate_from"
    assert_select "#reallocate_to", false
  end

  test "new 'to reallocation' should render correct edit form" do
    get new_subscription_event_path(subscriptions(:john)),
      params: { role: :reallocation, to: buckets(:john_checking_general).id }

    assert_response :ok
    assert_select "form#event_form[action=?]",
      subscription_events_path(subscriptions(:john), source: "new")
    assert_select "#reallocate_to"
    assert_select "#reallocate_from", false
  end

  # == API tests ========================================================================

  test "index HTML without a container should redirect to the user's root subscription" do
    sign_in :tim

    get events_path
    assert_redirected_to subscription_url(subscriptions(:tim))
  end

  test "index JSON without a container should return an explicit 400" do
    get events_path(format: :json)

    assert_response :bad_request
    assert @response.parsed_body["error"]
  end

  test "index via API should authenticate correctly via HTTP basic authentication" do
    sign_out

    get subscription_events_path(subscriptions(:john), format: :json),
      headers: basic_auth_headers(:john)
    assert_response :success
  end

  test "index via API should return first page of recent events for subscription" do
    get subscription_events_path(subscriptions(:john), format: :json)

    assert_response :success
    assert @response.parsed_body.any?
  end

  test "index via API should return first page of events for specified account" do
    get account_events_path(accounts(:john_checking), format: :json)

    assert_response :success
    assert @response.parsed_body.any?
  end

  test "index via API should return first page of events for specified bucket" do
    get bucket_events_path(buckets(:john_checking_dining), format: :json)

    assert_response :success
    assert @response.parsed_body.any?
  end

  test "index via API should return first page of events for specified tag" do
    get tag_events_path(tags(:john_lunch), format: :json)

    assert_response :success
    assert @response.parsed_body.any?
  end

  test "index via API with page and limit should return given page of events" do
    get bucket_events_path(buckets(:john_checking_dining), format: :json, page: 1, size: 2)

    assert_response :success
    json = @response.parsed_body
    assert_equal [events(:john_lunch_again).id, events(:john_lunch).id],
      json.map { |event| event["id"] }
  end

  test "index via API with include should return events with line items" do
    get bucket_events_path(buckets(:john_checking_dining), format: :json, include: "line_items")

    assert_response :success
    json = @response.parsed_body
    assert json.all? { |event| event["line_items"] }
  end

  test "index via API with include should return events with tagged items" do
    get bucket_events_path(buckets(:john_checking_dining), format: :json, include: "tagged_items")

    assert_response :success
    json = @response.parsed_body
    assert json.all? { |event| event["tagged_items"] }
  end

  test "show via API should return requested event record" do
    get event_path(events(:john_lunch), format: :json)

    assert_response :success
    json = @response.parsed_body
    assert_equal events(:john_lunch).id, json["id"]
  end

  test "new via API for reallocation should return template for reallocation" do
    get new_subscription_event_path(subscriptions(:john), format: :json, role: "reallocation")

    assert_response :success
    json = @response.parsed_body
    assert_equal ["primary", "reallocate_from | reallocate_to"],
      json["line_items"].map { |i| i["role"] }.sort
  end

  test "new via API for expense should return template for expense" do
    get new_subscription_event_path(subscriptions(:john), format: :json, role: "expense")

    assert_response :success
    json = @response.parsed_body
    assert_equal ["aside", "credit_options", "payment_source"],
      json["line_items"].map { |i| i["role"] }.sort
  end

  test "new via API for deposit should return template for deposit" do
    get new_subscription_event_path(subscriptions(:john), format: :json, role: "deposit")

    assert_response :success
    json = @response.parsed_body
    assert_equal ["deposit"], json["line_items"].map { |i| i["role"] }.sort
  end

  test "new via API for transfer should return template for transfer" do
    get new_subscription_event_path(subscriptions(:john), format: :json, role: "transfer")

    assert_response :success
    json = @response.parsed_body
    assert_equal ["transfer_from", "transfer_to"], json["line_items"].map { |i| i["role"] }.sort
  end

  test "create via API with validation errors should return 422 with errors" do
    data = simple_event(:john_checking, :john_checking_dining)
    data[:actor_name] = ""

    assert_no_difference -> { Event.count } do
      post subscription_events_path(subscriptions(:john), format: :json), params: { event: data }
      assert_response :unprocessable_entity
    end

    assert @response.parsed_body.key?("actor_name")
  end

  test "create via API should return 201 and new event record" do
    assert_difference -> { Event.count }, 1 do
      post subscription_events_path(subscriptions(:john), format: :json),
        params: { event: simple_event(:john_checking, :john_checking_dining) }
      assert_response :created
    end

    json = @response.parsed_body
    assert json.key?("id")
    assert @response.headers["Location"]
  end

  test "update via API with validation errors should return 422 with errors" do
    event = events(:john_checking_starting_balance)

    put event_path(event, format: :json),
      params: { event: { occurred_on: event.occurred_on.to_s, actor_name: "" } }

    assert_response :unprocessable_entity
    assert @response.parsed_body.key?("actor_name")
  end

  test "update via API should return 200 and updated event record" do
    event = events(:john_checking_starting_balance)

    put event_path(event, format: :json),
      params: { event: { occurred_on: event.occurred_on.to_s, actor_name: "Updated!" } }

    assert_response :success
    json = @response.parsed_body
    assert json.key?("id")
    assert_equal "Updated!", event.reload.actor_name
  end

  test "destroy via API should destroy record and return 200" do
    assert_difference -> { Event.count }, -1 do
      delete event_path(events(:john_lunch), format: :json)
      assert_response :success
    end
  end

  private
    def simple_event(account, bucket)
      {
        occurred_on: Date.today.to_s,
        actor_name: "Somebody",
        line_items: [
          {
            account_id: accounts(account).id.to_s,
            bucket_id: buckets(bucket).id.to_s,
            amount: "-2000",
            role: "payment_source"
          }
        ],
        tagged_items: []
      }
    end
end
