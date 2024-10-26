require 'test_helper'

class UserTest < ActiveSupport::TestCase
  # Setup method to create initial users
  setup do
    @user = User.new(email: 'test@example.com', password: 'Test@123', role: 'admin')
  end

  # Test for email presence validation
  test 'should not save user without email' do
    @user.email = nil
    assert_not @user.save, 'Saved the user without an email'
  end

  # Test for email uniqueness validation
  test 'should not save user with duplicate email' do
    duplicate_user = @user.dup
    @user.save
    assert_not duplicate_user.save, 'Saved a user with duplicate email'
  end

  # Test for role presence validation
  test 'should not save user without a role' do
    @user.role = nil
    assert_not @user.save, 'Saved the user without a role'
  end

  # Test for role inclusion validation
  test 'should only save user with a valid role' do
    @user.role = 'invalid_role'
    assert_not @user.save, 'Saved the user with an invalid role'
  end

  # Test password complexity validation
  test 'should not save user with a weak password' do
    @user.password = 'weakpassword'
    assert_not @user.save, 'Saved the user with a weak password'
  end

  # Test password complexity validation with valid password
  test 'should save user with a valid password' do
    @user.password = 'Strong@Password1'
    assert @user.save, "Couldn't save the user with a strong password"
  end

  # Test associations
  test 'should have many orders' do
    assert_respond_to @user, :orders
  end

  test 'should have many notifications' do
    assert_respond_to @user, :notifications
  end

  # Test custom methods: timeout_in
  test 'timeout_in should return 30 minutes' do
    assert_equal 30.minutes, @user.timeout_in
  end

  # Test custom methods: maximum_attempts
  test 'maximum_attempts should return correct values based on failed_attempts' do
    @user.failed_attempts = 2
    assert_equal 3, @user.maximum_attempts
    @user.failed_attempts = 3
    assert_equal 1, @user.maximum_attempts
  end

  # Test custom methods: unlock_in
  test 'unlock_in should return correct values based on failed_attempts' do
    @user.failed_attempts = 2
    assert_equal 5.minutes, @user.unlock_in
    @user.failed_attempts = 3
    assert_equal 10.minutes, @user.unlock_in
  end

  # Test custom method: jwt_token
  test 'jwt_token should return a valid JWT token' do
    @user.save
    assert_not_nil @user.jwt_token, 'JWT token should not be nil'
  end
end
