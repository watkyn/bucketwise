require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "authenticate should return user if password is correct" do
    assert_equal users(:john), User.authenticate("jjohnson", "testing")
  end

  test "authenticate should return nil if user_name is incorrect" do
    assert_nil User.authenticate("john", "testing")
  end

  test "authenticate should return nil if password is incorrect" do
    assert_nil User.authenticate("jjohnson", "test")
  end

  test "creating new user should set password_digest" do
    user = User.create(name: "Tom Thompson",
      email: "tthompson@domain.test", user_name: "tthompson",
      password: "thePassword", password_confirmation: "thePassword")
    assert user.password_digest.present?
    assert_equal user, User.authenticate("tthompson", "thePassword")
  end

  test "updating user's password should change password_digest" do
    old_digest = users(:john).password_digest
    users(:john).update!(password: "vamoose!", password_confirmation: "vamoose!")
    assert_not_equal old_digest, users(:john).reload.password_digest
    assert_nil User.authenticate("jjohnson", "testing")
    assert_equal users(:john), User.authenticate("jjohnson", "vamoose!")
  end

  test "creating new user with duplicate user name should fail" do
    assert_raises(ActiveRecord::RecordInvalid) do
      User.create!(name: "James Johnson",
        email: "james.johnson@domain.test", user_name: "jjohnson",
        password: "ponies!", password_confirmation: "ponies!")
    end
    error = assert_raises(ActiveRecord::RecordInvalid) do
      User.create!(name: "James Johnson",
        email: "james.johnson@domain.test", user_name: "jjohnson",
        password: "ponies!", password_confirmation: "ponies!")
    end
    assert error.record.errors[:user_name].any?
  end

  test "user as json should not emit password_digest or old hash" do
    json = users(:john).as_json
    assert_not json.key?("password_digest")
    assert_not json.key?("password_hash")
    assert_not json.key?("salt")
  end
end
