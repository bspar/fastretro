require "test_helper"

class NameOnlyDeliveryTest < ActionMailer::TestCase
  test "name-only mode suppresses email delivery and feedback even with configured mail settings" do
    FastRetro.stubs(:name_only?).returns(true)
    with_env("SITE_FEEDBACK_EMAIL" => "operator@example.com") do
      assert_nil FastRetro.site_feedback_email
      mail = MagicLinkMailer.sign_in_instructions(identities(:one).magic_links.create!).message
      assert_not mail.perform_deliveries
      assert_no_emails { mail.deliver }
    end
  end

  test "placeholder recipients cannot receive mail even outside name-only mode" do
    identity = Identity.create_name_only!
    link = identity.magic_links.create!
    mail = MagicLinkMailer.sign_in_instructions(link).message

    assert_not mail.perform_deliveries
    assert_no_emails { mail.deliver }
  end

  test "name-only mode does not schedule reminder email jobs" do
    FastRetro.stubs(:name_only?).returns(true)
    retro = retros(:one)
    assert_no_enqueued_jobs(only: Retro::RetentionReminderJob) { retro.update!(phase: :complete) }
  end

  test "already queued reminder jobs do not deliver in name-only mode" do
    FastRetro.stubs(:name_only?).returns(true)
    retro = retros(:one)
    retro.update_columns(phase: "complete", created_at: 8.days.ago)
    retros(:two).update_columns(created_at: 9.days.ago)
    retro.actions.create!(user: users(:one), status: :published, content: "Private action")

    assert_no_emails { Retro::RetentionReminderJob.perform_now(retro) }
    assert_nil retro.reload.retention_reminder_sent_at
  end
end
