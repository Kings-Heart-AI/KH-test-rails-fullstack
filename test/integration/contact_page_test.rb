require 'test_helper'

class ContactPageTest < ActionDispatch::IntegrationTest

  test "contact page renders with title" do
    get contact_path
    assert_response :success
    assert_select "title", "Contact | Ruby on Rails Tutorial Sample App"
    assert_select "h1", "Contact"
  end
end
