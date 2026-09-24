require "test_helper"

# Server-side integrity checks proving the page wiring Stimulus needs to boot
# is present in the rendered HTML (no browser gems required).
class FeBootTest < ActiveSupport::TestCase
  test "subscription show wires the events-form Stimulus controller" do
    html = rendered_subscription_page

    assert_match(/data-controller=['"]events-form( accounts-form)?['"]/, html,
                 "page must declare data-controller=\"events-form\" so Stimulus connects it")
    assert_match(/data-controller=['"]events-form accounts-form['"]/, html,
                 "page-level controller should include accounts-form as well")
  end

  test "expense link is bound to events-form#revealExpense" do
    html = rendered_subscription_page

    tag = opening_tag_for(html, /id=['"]expense_link['"]/)
    assert tag, "expected #expense_link on the subscription page"
    tag = CGI.unescapeHTML(tag)
    assert_includes tag, 'data-action="click->events-form#revealExpense"',
                    "#expense_link must trigger the Stimulus revealExpense action"
  end

  test "#new_event is a hidden events-form target" do
    html = rendered_subscription_page

    tag = opening_tag_for(html, /id=['"]new_event['"]/)
    assert tag, "expected #new_event on the subscription page"
    assert_match(/data-events-form-target=['"]newEvent['"]/, tag,
                 "#new_event must be registered as the newEvent target")
    assert_match(/class=['"][^'"]*\bhidden\b/, tag,
                 "#new_event must start hidden until revealExpense/Deposit/Transfer runs")
  end

  test "page loads an importmap with the pins Stimulus boot depends on" do
    html = rendered_subscription_page

    match = html.match(%r{<script type="importmap"[^>]*>(.*?)</script>}m)
    assert match, "rendered page must include javascript_importmap_tags output (importmap script tag)"

    imports = JSON.parse(match[1]).fetch("imports")
    %w[application @hotwired/stimulus controllers money].each do |pin|
      assert imports.key?(pin),
             "importmap must pin #{pin.inspect} for Stimulus boot; got keys: #{imports.keys.inspect}"
    end

    assert_match(/@hotwired\/stimulus-loading/, html,
                 "stimulus-loading module must be referenced so controllers auto-load")
  end

  test "recall fetch advances through the JSON response using the current event shape" do
    controller = Rails.root.join("app/javascript/controllers/events_form_controller.js").read

    assert_match(/this\.recallNext\(\)/, controller,
                 "recall fetch should advance through the loaded events")
    assert_match(/recalled\.event\s*\|\|\s*recalled/, controller,
                 "recall should accept the current bare event array as well as wrapped events")
    assert_match(/populate\s*!==\s*true/, controller,
                 "rehydrating split line items should restore their bucket and amount")
  end

  private

  # Logs in through the real stack (renderer-rendered assigns don't reach the
  # controller ivars that helper_method :subscription reads), then fetches the
  # subscription dashboard so we assert on genuine end-to-end HTML.
  def rendered_subscription_page
    return @rendered_subscription_page if @rendered_subscription_page

    session = ActionDispatch::Integration::Session.new(Rails.application)
    session.post("/session", params: { user_name: users(:john).user_name, password: "testing" })
    session.get("/subscriptions/#{subscriptions(:john).id}")

    assert_equal 200, session.response.status,
                 "subscription show should render (got #{session.response.status})"
    @rendered_subscription_page = session.response.body
  end

  # Returns the opening tag (<tag ...>) containing the first match of the
  # given pattern (a Regexp matching an attribute and its value).
  def opening_tag_for(html, attribute_pattern)
    match = html.match(attribute_pattern)
    return nil unless match

    idx = match.begin(0)
    start = html.rindex("<", idx)
    finish = html.index(">", idx)
    return nil unless start && finish && start < finish

    html[start..finish]
  end
end
