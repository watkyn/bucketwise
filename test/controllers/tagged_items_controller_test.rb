require "test_helper"

class TaggedItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in :john
  end

  # == API tests ========================================================================

  test "create via API for inaccessible event should 404" do
    assert_no_difference -> { TaggedItem.count } do
      post event_tagged_items_path(events(:tim_checking_starting_balance), format: :json),
        params: { tagged_item: { amount: 100, tag_id: tags(:john_tip).id } }
      assert_response :not_found
    end
  end

  test "create via API for inaccessible tag should 404" do
    assert_no_difference -> { TaggedItem.count } do
      post event_tagged_items_path(events(:john_lunch), format: :json),
        params: { tagged_item: { amount: 100, tag_id: tags(:tim_milk).id } }
      assert_response :not_found
    end
  end

  test "create via API should add tagged item and return 201" do
    assert_difference -> { TaggedItem.count } do
      post event_tagged_items_path(events(:john_lunch), format: :json),
        params: { tagged_item: { amount: 100, tag_id: tags(:john_fuel).id } }
      assert_response :created
    end

    json = @response.parsed_body
    assert json.key?("id")
    assert events(:john_lunch).reload.tagged_items.any? { |item| item.tag == tags(:john_fuel) }
  end

  test "create via API should allow tag to be specified by name" do
    assert_difference -> { TaggedItem.count } do
      assert_difference -> { Tag.count } do
        post event_tagged_items_path(events(:john_lunch), format: :json),
          params: { tagged_item: { amount: 100, tag_id: "n:misc" } }
        assert_response :created
      end
    end

    json = @response.parsed_body
    assert json.key?("id")
    assert events(:john_lunch).reload.tagged_items.any? { |item| item.tag.name == "misc" }
  end

  test "destroy via API for inaccessible tagged item should 404" do
    sign_in :tim

    assert_no_difference -> { TaggedItem.count } do
      delete tagged_item_path(tagged_items(:john_lunch_tip), format: :json)
      assert_response :not_found
    end
  end

  test "destroy via API should remove tagged item from event and return 200" do
    assert_difference -> { TaggedItem.count }, -1 do
      delete tagged_item_path(tagged_items(:john_lunch_tip), format: :json)
      assert_response :ok
    end
  end
end
