require 'test_helper'

class FollowListsTest < ActionDispatch::IntegrationTest

  def setup
    @user      = users(:michael)
    @unrelated = users(:user_0)
    log_in_as(@user)
  end

  test "following page renders show_follow with title, stats and avatars" do
    get following_user_path(@user)
    assert_response :success
    assert_template 'users/show_follow'
    assert_select 'title', "Following | Ruby on Rails Tutorial Sample App"
    assert_select 'h3', "Following"
    assert_select 'h1', @user.name
    assert_select 'a[href=?]', user_path(@user), text: "view my profile"
    assert_select 'a[href=?]', following_user_path(@user)
    assert_select 'a[href=?]', followers_user_path(@user)
    assert_select 'strong#following', @user.following.count.to_s
    assert_select 'strong#followers', @user.followers.count.to_s
    assert_not @user.following.empty?
    assert_select 'div.user_avatars' do
      @user.following.each do |user|
        assert_select 'a[href=?]', user_path(user)
      end
    end
    assert_select 'ul.users' do
      assert_select 'li', @user.following.count
      @user.following.each do |user|
        assert_select 'a[href=?]', user_path(user), text: user.name
      end
    end
  end

  test "followers page renders show_follow with title, stats and avatars" do
    get followers_user_path(@user)
    assert_response :success
    assert_template 'users/show_follow'
    assert_select 'title', "Followers | Ruby on Rails Tutorial Sample App"
    assert_select 'h3', "Followers"
    assert_select 'h1', @user.name
    assert_select 'a[href=?]', following_user_path(@user)
    assert_select 'a[href=?]', followers_user_path(@user)
    assert_select 'strong#following', @user.following.count.to_s
    assert_select 'strong#followers', @user.followers.count.to_s
    assert_not @user.followers.empty?
    assert_select 'div.user_avatars' do
      @user.followers.each do |user|
        assert_select 'a[href=?]', user_path(user)
      end
    end
    assert_select 'ul.users' do
      assert_select 'li', @user.followers.count
      @user.followers.each do |user|
        assert_select 'a[href=?]', user_path(user), text: user.name
      end
    end
  end

  test "user with no relationships shows empty following page" do
    assert @unrelated.following.empty?
    get following_user_path(@unrelated)
    assert_response :success
    assert_template 'users/show_follow'
    assert_select 'h3', "Following"
    assert_select 'strong#following', "0"
    assert_select 'strong#followers', "0"
    assert_select 'div.user_avatars', count: 0
    assert_select 'ul.users', count: 0
    assert_select 'div.pagination', count: 0
  end

  test "user with no relationships shows empty followers page" do
    assert @unrelated.followers.empty?
    get followers_user_path(@unrelated)
    assert_response :success
    assert_template 'users/show_follow'
    assert_select 'h3', "Followers"
    assert_select 'strong#following', "0"
    assert_select 'strong#followers', "0"
    assert_select 'div.user_avatars', count: 0
    assert_select 'ul.users', count: 0
    assert_select 'div.pagination', count: 0
  end

  test "followers page paginates when there are more than 30 followers" do
    (0..29).each do |n|
      users("user_#{n}").follow(@user)
    end
    assert_equal 32, @user.followers.count
    get followers_user_path(@user)
    assert_template 'users/show_follow'
    assert_select 'strong#followers', "32"
    assert_select 'div.pagination'
    assert_select 'ul.users li', 30
    assert_select 'div.pagination a[href=?]', followers_user_path(@user, page: 2)
  end

  test "followers page without pagination for few followers" do
    get followers_user_path(@user)
    assert_select 'div.pagination', count: 0
  end
end
