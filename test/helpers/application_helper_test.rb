require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "visibility helper hides false flags only" do
    assert_nil visible?(true)
    assert_equal "display: none", visible?(false)
  end

  test "currency helper formats cents and forwards formatting options" do
    assert_equal "$1,234.56", format_cents(123456)
    assert_equal "€1,234.56", format_cents(123456, unit: "€")
  end

  test "revision and deployment helpers provide sensible values without a revision file" do
    revision_file = Rails.root.join("REVISION")

    if revision_file.exist?
      assert_equal revision_file.read.strip, application_revision
      assert_match(/ago\z/, application_last_deployed)
    else
      assert_equal "HEAD", application_revision
      assert_equal "(not deployed)", application_last_deployed
    end
  end
end
