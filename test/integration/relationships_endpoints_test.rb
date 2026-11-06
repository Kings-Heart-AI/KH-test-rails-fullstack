require 'test_helper'

class RelationshipsEndpointsTest < ActionDispatch::IntegrationTest

  def setup
    @user  = users(:michael)
    @other = users(:archer)
    log_in_as(@user)
  end

  test "standard create adds one relationship and redirects to the user" do
    assert_not @user.following?(@other)
    assert_difference 'Relationship.count', 1 do
      post relationships_path, followed_id: @other.id
    end
    relationship = Relationship.order(:id).last
    assert_equal @user.id,  relationship.follower_id
    assert_equal @other.id, relationship.followed_id
    assert_redirected_to @other
    follow_redirect!
    assert_template 'users/show'
    assert_select 'div#follow_form input[value=?]', 'Unfollow'
  end

  test "xhr create adds one relationship and renders the unfollow form" do
    assert_not @user.following?(@other)
    assert_difference 'Relationship.count', 1 do
      xhr :post, relationships_path, followed_id: @other.id
    end
    relationship = Relationship.order(:id).last
    assert_equal @user.id,  relationship.follower_id
    assert_equal @other.id, relationship.followed_id
    assert_response :success
    assert_equal 'text/javascript', response.content_type.to_s
    assert_match '#follow_form', response.body
    assert_match 'Unfollow', response.body
    assert_no_match(/value=\\"Follow\\"/, response.body)
    assert_match "$(\"#followers\").html('#{@other.followers.count}');", response.body
    assert_equal 1, @other.followers.count
  end

  test "standard destroy removes the relationship and redirects to the user" do
    @user.follow(@other)
    relationship = @user.active_relationships.find_by(followed_id: @other.id)
    assert_difference 'Relationship.count', -1 do
      delete relationship_path(relationship)
    end
    assert_not Relationship.exists?(relationship.id)
    assert_not @user.following?(@other)
    assert_redirected_to @other
    follow_redirect!
    assert_template 'users/show'
    assert_select 'div#follow_form input[value=?]', 'Follow'
  end

  test "xhr destroy removes the relationship and renders the follow form" do
    @user.follow(@other)
    relationship = @user.active_relationships.find_by(followed_id: @other.id)
    assert_equal 1, @other.followers.count
    assert_difference 'Relationship.count', -1 do
      xhr :delete, relationship_path(relationship)
    end
    assert_not Relationship.exists?(relationship.id)
    assert_response :success
    assert_equal 'text/javascript', response.content_type.to_s
    assert_match '#follow_form', response.body
    assert_match 'value=\"Follow\"', response.body
    assert_no_match(/Unfollow/, response.body)
    assert_match "$(\"#followers\").html('0');", response.body
  end
end
