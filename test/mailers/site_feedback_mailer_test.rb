require "test_helper"

class SiteFeedbackMailerTest < ActionMailer::TestCase
  test "feedback uses only the explicitly configured recipient" do
    with_env("SITE_FEEDBACK_EMAIL" => "retro-support@internal.example") do
      email = SiteFeedbackMailer.notify(message: "Private feedback", from_email: "user@internal.example", from_name: "Team member")

      assert_equal [ "retro-support@internal.example" ], email.to
      assert_equal [ "user@internal.example" ], email.reply_to
      assert_not_includes email.body.encoded, "support@fastretro.app"
    end
  end

  test "feedback has no upstream recipient fallback" do
    with_env("SITE_FEEDBACK_EMAIL" => nil) do
      assert_raises(KeyError) do
        SiteFeedbackMailer.notify(message: "Private feedback", from_email: "user@internal.example", from_name: "Team member").message
      end
    end
  end
end
