require "test_helper"

class EventsHelperTest < ActionView::TestCase
  include ERB::Util

  test "form sections include transaction legs and tags" do
    assert_equal %w[payment_source credit_options deposit transfer_from transfer_to reallocate_from reallocate_to tags],
      form_sections
  end

  test "account and bucket selectors reflect available choices" do
    html = select_account(:payment_source, [accounts(:john_checking)], nil)
    options = Nokogiri::HTML.fragment(html).css("option")
    assert_equal ["", accounts(:john_checking).id.to_s], options.map { |option| option["value"] }

    selected_html = select_account(:payment_source, [accounts(:john_checking)], accounts(:john_checking).id)
    refute_includes selected_html, '<option value=""></option>'

    @line_item = line_items(:john_lunch_checking_dining)
    bucket_html = select_bucket(:credit_options, line_item: @line_item)
    bucket_fragment = Nokogiri::HTML.fragment(bucket_html)
    assert bucket_fragment.at_css("option[value='+']"),
      "expected a real '-- More than one --' option, got: #{bucket_html}"
    assert bucket_fragment.at_css("option[value='++']"),
      "expected a real '-- Add a new bucket --' option, got: #{bucket_html}"
    refute_includes bucket_html, "&lt;option",
      "expected real <option> elements in the bucket selector, found escaped HTML instead"

    unspecific_bucket_html = select_bucket(:deposit)
    assert_includes unspecific_bucket_html, "-- Select an account --"
    assert_match(/disabled/, unspecific_bucket_html)
  end

  test "account data and account links use real bucket and account values" do
    @subscription = subscriptions(:john)
    account_data = accounts_with_buckets
    savings = account_data.fetch(accounts(:john_savings).id)

    assert_equal "Savings", savings[:name]
    assert_equal ["General", "Aside"], savings[:buckets].map { |bucket| bucket[:name] }
    assert_equal "r:aside", savings[:buckets].last[:id]

    html = links_to_accounts_for_event(events(:john_lunch))
    assert_includes html, account_path(accounts(:john_checking))
    assert_includes html, account_path(accounts(:john_mastercard))
  end

  test "event form helpers select paths, amounts, tags, and fallback values" do
    @subscription = subscriptions(:john)
    @event = events(:john_lunch)
    @action_name_for_test = "new"

    assert_same @event, event_for_form
    assert_equal "new", event_form_source
    assert_equal event_path(@event), event_form_action
    assert_equal "7.75", event_amount_value
    assert_equal "7.75", line_item_amount_value(line_items(:john_lunch_mastercard))
    assert_equal "", line_item_amount_value(nil)
    assert_equal "lunch", tagged_item_name_value(tagged_items(:john_lunch_lunch))
    assert_equal "7.75", tagged_item_amount_value(tagged_items(:john_lunch_lunch))
    assert_equal "lunch", tag_list_for_event

    @event = nil
    assert_instance_of Event, event_for_form
    assert_equal subscription_events_path(@subscription, source: "new"), event_form_action
    assert_equal "", event_amount_value
    assert_equal "", tagged_item_name_value(nil)
    assert_equal "", tagged_item_amount_value(nil)
    assert_equal "", tag_list_for_event

    @event = Event.new(role: "expense")
    assert_equal "0.00", event_amount_value

    @event = events(:john_bill_pay)
    assert_equal "7.75", event_amount_value
    assert event_wants_section?(:transfer_from)
    assert event_wants_section?(:transfer_to)

    @event = events(:john_checking_starting_balance)
    assert event_wants_section?(:deposit)

    @event = nil
    @action_name_for_test = "edit"
    assert_nil event_form_source
    assert event_wants_section?(:general_information)
    assert section_visible_for_event?(:credit_options)
    refute event_has_tags?
    refute event_has_partial_tags?
  end

  test "event role controls sections, check options, repayments, and tags" do
    @event = events(:john_lunch)

    assert section_wants_check_options?(:payment_source)
    assert section_wants_check_options?(:deposit)
    assert section_wants_check_options?(:transfer_from)
    refute section_wants_check_options?(:credit_options)
    assert section_wants_repayment_options?(:payment_source)
    refute section_wants_repayment_options?(:deposit)
    refute event_wants_memo?
    assert event_wants_section?("payment_source")
    assert event_wants_section?(:tags)
    refute event_wants_section?(:deposit)
    assert event_has_tags?
    assert event_has_partial_tags?
    assert section_visible_for_event?(:credit_options)
    @event = events(:john_bill_pay)
    assert check_options_visible_for?(:transfer_from)
    @event = events(:john_lunch)
    refute repayment_options_visible_for?(:payment_source)

    @event = events(:john_bare_mastercard)
    assert repayment_options_visible_for?(:payment_source)
    refute section_visible_for_event?(:credit_options)

    @event = events(:john_reallocate_from)
    refute event_wants_section?(:general_information)
    assert event_wants_section?(:reallocate_from)
    refute event_wants_section?(:reallocate_to)
  end

  test "memo, bucket visibility, and section item iterators reflect the event" do
    @event = events(:john_lunch)
    @event.memo = "lunch with team"

    assert event_wants_memo?
    assert section_has_single_bucket?(:payment_source)
    refute multi_bucket_visible?(:payment_source)
    assert_equal line_items(:john_lunch_mastercard), line_item_for_section(:payment_source)
    assert_equal accounts(:john_mastercard).id, account_id_for_section(:payment_source)

    items = []
    for_each_line_item_in(:payment_source) { |item| items << item }
    assert_equal [line_items(:john_lunch_mastercard)], items

    partial_tags = []
    for_each_partial_tagged_item { |item| partial_tags << item }
    assert_equal [tagged_items(:john_lunch_tip)], partial_tags

    @event = Event.new(role: "expense")
    @event.line_items.build(role: "payment_source")
    @event.line_items.build(role: "payment_source")
    refute section_has_single_bucket?(:payment_source)
    assert multi_bucket_visible?(:payment_source)
  end

  test "action phrases reject unsupported sections" do
    assert_equal "was drawn from", bucket_action_phrase_for(:payment_source)
    assert_equal "will be repaid from", bucket_action_phrase_for(:credit_options)
    assert_equal "was deposited to", bucket_action_phrase_for(:deposit)
    assert_equal "was transferred from", bucket_action_phrase_for(:transfer_from)
    assert_equal "was transferred to", bucket_action_phrase_for(:transfer_to)

    assert_raises(ArgumentError) { bucket_action_phrase_for(:reallocate_from) }
  end

  test "form section rendering supplies the correct fields and account choices" do
    @subscription = subscriptions(:john)
    @event = events(:john_lunch)
    form = ActionView::Helpers::FormBuilder.new(:event, @event, self, {})

    html = render_event_form_section(form, :credit_options)
    fragment = Nokogiri::HTML.fragment(html)

    assert_equal "Repayment Options", fragment.at_css("legend").text
    assert fragment.at_css("#account_for_credit_options option[value='#{accounts(:john_checking).id}']")
    refute fragment.at_css("#account_for_credit_options option[value='#{accounts(:john_mastercard).id}']")
    assert fragment.at_css("select.bucket_for_credit_options")
    assert fragment.at_css("div[id='credit_options.multiple_buckets'].hidden")

    reallocation = events(:john_reallocate_from)
    @event = reallocation
    realloc_form = ActionView::Helpers::FormBuilder.new(:event, reallocation, self, {})
    realloc_html = render_event_form_section(realloc_form, :reallocate_from)
    assert_includes realloc_html, "Reallocate funds"
    assert_includes realloc_html, "reallocating funds"
    refute_includes realloc_html, "-- More than one --"

    @event = events(:john_lunch)
    tags_html = render_event_form_section(form, :tags)
    tags_fragment = Nokogiri::HTML.fragment(tags_html)
    assert tags_fragment.at_css("fieldset#tags")
    assert_equal "lunch", tags_fragment.at_css("#event_tags_list")["value"]
    assert_equal 1, tags_fragment.css("#tagged_items li").length
  end

  test "tag links are sorted and tag entry fields include their dropdown" do
    @subscription = subscriptions(:john)
    html = tag_links_for(events(:john_lunch))
    assert_operator html.index("lunch"), :<, html.index("tip")
    assert_includes html, tag_path(tags(:john_lunch))

    field = tag_entry_field("event[tags]", "lunch", id: "tag_names", multiple: true)
    doc = Nokogiri::HTML(field)
    assert_equal "event[tags]", doc.at_css("input")[:name]
    assert_equal "tag_names_select", doc.at_css("ul[data-autocomplete-target='list']")[:id]
    assert_equal ",", doc.at_css("div[data-autocomplete-tokens-value]")[:"data-autocomplete-tokens-value"]
    assert_includes doc.at_css("div[data-controller='autocomplete']")[:"data-autocomplete-items-value"], "lunch"

    list = doc.at_css("ul[data-autocomplete-target='list']")
    controller = list.ancestors("[data-controller~='autocomplete']").first
    assert controller, "expected tag dropdown to stay inside its autocomplete controller after HTML parsing"
    assert controller.at_css("input[data-autocomplete-target='input']")
  end

  test "reallocation verbs and partial templates map each form section" do
    assert_equal %w[from to], reallocation_verbs_for(:reallocate_from)
    assert_equal %w[to from], reallocation_verbs_for(:reallocate_to)
    assert_raises(ArgumentError) { reallocation_verbs_for(:payment_source) }

    assert_equal "events/tagged_item", template_partial_for("tags")
    assert_equal "events/reallocation_item", template_partial_for("reallocate_from")
    assert_equal "events/reallocation_item", template_partial_for("reallocate_to")
    assert_equal "events/line_item", template_partial_for("payment_source")
    assert_predicate emit_account_data_assignments, :html_safe?
    assert_empty emit_account_data_assignments
  end

  private

    def subscription
      @subscription
    end

    def action_name
      @action_name_for_test || "edit"
    end
end
