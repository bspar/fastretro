require "test_helper"

class ApplicationMailerTest < ActionMailer::TestCase
  test "production mail fails closed without private deployment settings" do
    Rails.env.stubs(:production?).returns(true)
    magic_link = MagicLink.create!(identity: identities(:admin))

    %w[ APP_HOST MAILER_FROM_ADDRESS SMTP_ADDRESS ].each do |setting|
      with_env("APP_HOST" => "retro.internal.example", "MAILER_FROM_ADDRESS" => "retro@internal.example", "SMTP_ADDRESS" => "mail.internal.example", setting => nil) do
        error = assert_raises(ArgumentError) { MagicLinkMailer.sign_in_instructions(magic_link).message }
        assert_includes error.message, setting
      end
    end
  end

  test "login mail does not advertise upstream support" do
    magic_link = MagicLink.create!(identity: identities(:admin))

    with_env("SITE_FEEDBACK_EMAIL" => nil) do
      email = MagicLinkMailer.sign_in_instructions(magic_link)

      assert_not_includes email.body.encoded, "support@fastretro.app"
      assert_not_includes email.from, "support@fastretro.app"
    end
  end

  test "configured support address is used in login mail" do
    magic_link = MagicLink.create!(identity: identities(:admin))

    with_env("SITE_FEEDBACK_EMAIL" => "retro-support@internal.example") do
      assert_includes MagicLinkMailer.sign_in_instructions(magic_link).body.encoded, "retro-support@internal.example"
    end
  end
end
