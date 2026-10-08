require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "production pages never include upstream analytics" do
    Rails.env.stubs(:production?).returns(true)

    assert_nil analytics_tag
  end

  test "legacy analytics environment variable cannot enable tracking" do
    with_env("ANALYTICS" => "true") { assert_nil analytics_tag }
  end
end
