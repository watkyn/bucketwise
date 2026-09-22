require "test_helper"

class TagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  test "show should 404 for invalid tag" do
    assert_not Tag.exists?(1)

    get tag_path(1)
    assert_response :not_found
  end

  test "show should 404 for inaccessible tag" do
    get tag_path(tags(:tim_milk))
    assert_response :not_found
  end

  test "show should display tag perma page for requested tag" do
    get tag_path(tags(:john_lunch))

    assert_response :ok
    assert_select "h2#name", text: /Transactions tagged "lunch"/
    assert_select "#balance", text: "$7.75"
    assert_select "table.entries tr[id=?]", "event_#{events(:john_lunch).id}"
  end

  test "update should 404 for inaccessible tag" do
    put tag_path(tags(:tim_milk)), params: { tag: { name: "hijacked!" } }, as: :turbo_stream

    assert_response :not_found
    assert_equal "milk", tags(:tim_milk).reload.name
  end

  test "update should change tag name and render turbo stream response" do
    put tag_path(tags(:john_lunch)), params: { tag: { name: "hijacked!" } }, as: :turbo_stream

    assert_response :ok
    assert_equal "text/vnd.turbo-stream.html", @response.media_type
    assert_select "turbo-stream[action=?][target=?]", "replace", "name"
    assert_select "h2#name", text: /Transactions tagged "hijacked!"/
    assert_equal "hijacked!", tags(:john_lunch).reload.name
  end

  test "destroy should 404 for inaccessible tag" do
    assert_no_difference -> { Tag.count } do
      assert_no_difference -> { TaggedItem.count } do
        delete tag_path(tags(:tim_milk))
        assert_response :not_found
      end
    end
  end

  test "destroy should remove tag and all associated tagged items" do
    item = tagged_items(:john_lunch_lunch)

    assert_difference -> { Tag.count }, -1 do
      assert_difference -> { TaggedItem.count }, -1 do
        delete tag_path(tags(:john_lunch))
      end
    end

    assert_redirected_to subscription_path(subscriptions(:john))
    assert_not Tag.exists?(tags(:john_lunch).id)
    assert_not TaggedItem.exists?(item.id)
  end

  test "merge should 404 when target tag is inaccessible" do
    assert_no_difference -> { Tag.count } do
      assert_no_difference -> { TaggedItem.count } do
        delete tag_path(tags(:john_lunch)), params: { receiver_id: tags(:tim_milk).id }
        assert_response :not_found
      end
    end
  end

  test "merge should 422 when target tag is same as deleted tag" do
    assert_no_difference -> { Tag.count } do
      assert_no_difference -> { TaggedItem.count } do
        delete tag_path(tags(:john_lunch)), params: { receiver_id: tags(:john_lunch).id }
        assert_response :unprocessable_entity
      end
    end
  end

  test "merge should remove tag and move all associated tagged items to target tag" do
    item = tagged_items(:john_lunch_lunch)
    balance = tags(:john_fuel).balance

    delete tag_path(tags(:john_lunch)), params: { receiver_id: tags(:john_fuel).id }

    assert_redirected_to tag_path(tags(:john_fuel))
    assert_not Tag.exists?(tags(:john_lunch).id)
    assert_equal tags(:john_fuel), item.reload.tag
    assert_equal balance + item.amount, tags(:john_fuel).reload.balance
  end

  # == API tests ========================================================================

  test "index via API for inaccessible subscription should 404" do
    get subscription_tags_path(subscriptions(:tim), format: :json)
    assert_response :not_found
  end

  test "index via API should return list of all tags for given subscription" do
    get subscription_tags_path(subscriptions(:john), format: :json)

    assert_response :ok
    json = @response.parsed_body
    assert json.is_a?(Array)
    assert json.any?
    assert_equal subscriptions(:john).tags.pluck(:id).sort, json.map { |tag| tag["id"] }.sort
  end

  test "show via API should return record for the given tag" do
    get tag_path(tags(:john_tip), format: :json)

    assert_response :ok
    json = @response.parsed_body
    assert_equal tags(:john_tip).id, json["id"]
  end

  test "new via API should return template record" do
    get new_subscription_tag_path(subscriptions(:john), format: :json)

    assert_response :ok
    json = @response.parsed_body
    assert json.key?("name")
    assert_not json["id"]
  end

  test "create via API for inaccessible subscription should 404" do
    assert_no_difference -> { Tag.count } do
      post subscription_tags_path(subscriptions(:tim), format: :json),
        params: { tag: { name: "testing" } }
      assert_response :not_found
    end
  end

  test "create via API should return 201 and set location header" do
    assert_difference -> { Tag.count } do
      post subscription_tags_path(subscriptions(:john), format: :json),
        params: { tag: { name: "testing" } }

      assert_response :created
      assert @response.headers["Location"]
      json = @response.parsed_body
      assert json.key?("id")
    end
  end

  test "create via API should return 422 with errors if validations fail" do
    assert_no_difference -> { Tag.count } do
      post subscription_tags_path(subscriptions(:john), format: :json),
        params: { tag: { name: "tip" } }

      assert_response :unprocessable_entity
      json = @response.parsed_body
      assert json.key?("name")
    end
  end

  test "update via API for inaccessible tag should 404" do
    put tag_path(tags(:tim_milk), format: :json), params: { tag: { name: "milkshake" } }

    assert_response :not_found
    assert_equal "milk", tags(:tim_milk).reload.name
  end

  test "update via API should change tag name and return 200" do
    put tag_path(tags(:john_tip), format: :json), params: { tag: { name: "gratuity" } }

    assert_response :ok
    json = @response.parsed_body
    assert json.key?("id")
    assert_equal "gratuity", tags(:john_tip).reload.name
  end

  test "update via API should return 422 with errors if validations fail" do
    put tag_path(tags(:john_tip), format: :json), params: { tag: { name: "lunch" } }

    assert_response :unprocessable_entity
    json = @response.parsed_body
    assert json.key?("name")
    assert_equal "tip", tags(:john_tip).reload.name
  end

  test "destroy via API should remove tag and return 200" do
    assert_difference -> { Tag.count }, -1 do
      delete tag_path(tags(:john_tip), format: :json)
      assert_response :ok
    end
  end
end
