require 'test_helper'

class FollowListsLoggedOutTest < ActionDispatch::IntegrationTest

  def setup
    @user = users(:michael)
  end

  test "logged-out following page redirects to login with flash" do
    get following_user_path(@user)
    assert_redirected_to login_url
    assert_equal "Please log in.", flash[:danger]
    follow_redirect!
    assert_template 'sessions/new'
    assert_select "div.alert-danger", "Please log in."
  end

  test "logged-out followers page redirects to login with flash" do
    get followers_user_path(@user)
    assert_redirected_to login_url
    assert_equal "Please log in.", flash[:danger]
    follow_redirect!
    assert_template 'sessions/new'
    assert_select "div.alert-danger", "Please log in."
  end

  test "login forwards to the requested following page" do
    get following_user_path(@user)
    assert_redirected_to login_url
    log_in_as(@user)
    assert_redirected_to following_user_url(@user)
    follow_redirect!
    assert_template 'users/show_follow'
  end

  test "login forwards to the requested followers page" do
    get followers_user_path(@user)
    assert_redirected_to login_url
    log_in_as(@user)
    assert_redirected_to followers_user_url(@user)
    follow_redirect!
    assert_template 'users/show_follow'
  end
end
