require 'test_helper'

class RelationshipsLoggedOutTest < ActionDispatch::IntegrationTest

  def setup
    @other        = users(:archer)
    @relationship = Relationship.first
  end

  test "create redirects to login when logged out" do
    assert_no_difference 'Relationship.count' do
      post relationships_path, followed_id: @other.id
    end
    assert_redirected_to login_url
    assert_equal 'Please log in.', flash[:danger]
  end

  test "create via xhr redirects to login when logged out" do
    assert_no_difference 'Relationship.count' do
      xhr :post, relationships_path, followed_id: @other.id
    end
    assert_redirected_to login_url
    assert_equal 'Please log in.', flash[:danger]
  end

  test "destroy redirects to login when logged out" do
    assert_not_nil @relationship
    assert_no_difference 'Relationship.count' do
      delete relationship_path(@relationship)
    end
    assert_redirected_to login_url
    assert_equal 'Please log in.', flash[:danger]
  end

  test "destroy via xhr redirects to login when logged out" do
    assert_not_nil @relationship
    assert_no_difference 'Relationship.count' do
      xhr :delete, relationship_path(@relationship)
    end
    assert_redirected_to login_url
    assert_equal 'Please log in.', flash[:danger]
  end
end
