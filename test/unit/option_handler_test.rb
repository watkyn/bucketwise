require "test_helper"

class OptionHandlerTest < ActiveSupport::TestCase
  include OptionHandler

  test "appending arrays concatenates arrays or appends a scalar" do
    options = { include: [:account] }

    append_to_options(options, :include, [:buckets])
    append_to_options(options, :include, :author)

    assert_equal [:account, :buckets, :author], options[:include]
  end

  test "appending a hash to an array promotes the option to a hash" do
    options = { include: [:account] }

    append_to_options(options, :include, buckets: { only: :name })

    assert_equal({ buckets: { only: :name }, account: {} }, options[:include])
  end

  test "appending arrays and hashes to a hash preserves existing option values" do
    options = { include: { account: { only: :name } } }

    append_to_options(options, :include, [:buckets, :account])
    append_to_options(options, :include, account: { only: :id }, author: { only: :name })

    assert_equal({ account: { only: :name }, buckets: {}, author: { only: :name } }, options[:include])
  end

  test "appending a scalar to a hash creates an empty option unless it exists" do
    options = { include: { account: { only: :name } } }

    append_to_options(options, :include, :account)
    append_to_options(options, :include, :buckets)

    assert_equal({ account: { only: :name }, buckets: {} }, options[:include])
  end

  test "a scalar option is replaced by the supplied value" do
    options = { include: :account }

    append_to_options(options, :include, [:buckets])

    assert_equal [:buckets], options[:include]
  end
end
