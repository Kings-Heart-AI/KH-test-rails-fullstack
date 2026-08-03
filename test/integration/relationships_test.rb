require 'test_helper'

class RelationshipsTest < ActionDispatch::IntegrationTest

  def setup
    @michael = users(:michael)
    @archer  = users(:archer)
  end

  test "should follow a user with full state transition" do
    log_in_as(@michael)
    following_before = @michael.following.count
    followers_before = @archer.followers.count
    assert_difference('Relationship.count', 1) do
      post relationships_path, followed_id: @archer.id
    end
    assert @michael.reload.following?(@archer)
    assert_equal following_before + 1, @michael.following.count
    assert_equal followers_before + 1, @archer.reload.followers.count
    assert_redirected_to @archer
  end

  test "should unfollow a user with full state transition" do
    log_in_as(@michael)
    relationship = relationships(:one)
    lana = users(:lana)
    following_before = @michael.following.count
    followers_before = lana.followers.count
    assert_difference('Relationship.count', -1) do
      delete relationship_path(relationship)
    end
    assert_not @michael.reload.following?(lana)
    assert_equal following_before - 1, @michael.following.count
    assert_equal followers_before - 1, lana.reload.followers.count
    assert_redirected_to lana
  end

  test "should redirect create when not logged in" do
    assert_no_difference('Relationship.count') do
      post relationships_path, followed_id: @archer.id
    end
    assert_redirected_to login_url
  end

  test "should redirect destroy when not logged in" do
    relationship = @michael.active_relationships.create!(followed_id: @archer.id)
    assert_no_difference('Relationship.count') do
      delete relationship_path(relationship)
    end
    assert_redirected_to login_url
  end

  test "should redirect create via Ajax when not logged in" do
    assert_no_difference('Relationship.count') do
      xhr :post, relationships_path, followed_id: @archer.id
    end
    assert_redirected_to login_url
  end

  test "should redirect destroy via Ajax when not logged in" do
    relationship = @michael.active_relationships.create!(followed_id: @archer.id)
    assert_no_difference('Relationship.count') do
      xhr :delete, relationship_path(relationship)
    end
    assert_redirected_to login_url
  end

  test "should follow a user with Ajax and render create.js.erb" do
    log_in_as(@michael)
    assert_difference('Relationship.count', 1) do
      xhr :post, relationships_path, followed_id: @archer.id
    end
    assert_response :success
    assert_template 'relationships/create'
  end

  test "should unfollow a user with Ajax and render destroy.js.erb" do
    log_in_as(@michael)
    relationship = relationships(:two)
    assert_difference('Relationship.count', -1) do
      xhr :delete, relationship_path(relationship)
    end
    assert_response :success
    assert_template 'relationships/destroy'
  end
end
