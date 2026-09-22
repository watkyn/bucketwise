require "test_helper"

class TagsHelperTest < ActionView::TestCase
  test "possible receiver tags excludes the current tag and sorts by name" do
    @subscription = subscriptions(:john)
    @tag_ref = tags(:john_lunch)

    assert_equal ["fuel", "tip"], possible_receiver_tags.map(&:name)
    refute_includes possible_receiver_tags, @tag_ref
  end

  private

    def subscription
      @subscription
    end

    def tag_ref
      @tag_ref
    end
end
