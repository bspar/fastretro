require "test_helper"

class SelfHostedPrivacyTest < ActionDispatch::IntegrationTest
  setup do
    FastRetro.stubs(:saas?).returns(false)
    FastRetro.stubs(:site_feedback_email).returns(nil)
    sign_in_as :one
  end

  test "self-hosted pages omit tracking and unconfigured feedback links" do
    get retros_path

    assert_response :success
    assert_select "script[src^='http']", count: 0
    assert_select "a[href='#{new_site_feedback_path(script_name: nil)}']", count: 0
    assert_not_includes response.body, "analytics.cengizg.com"
  end

  test "retro pages enforce local-resource CSP without upstream scripts" do
    get retro_waiting_room_path(retros(:one))

    assert_response :success
    assert_select "script[src^='http']", count: 0
    assert_select "a[href='#{new_site_feedback_path(script_name: nil)}']", count: 0
    policy = response.headers.fetch("Content-Security-Policy")
    # Form actions depend on boot-time SaaS mode; the production check covers them.
    %w[ script-src connect-src img-src font-src media-src ].each do |directive|
      sources = policy.split(";").find { |entry| entry.strip.start_with?("#{directive} ") }
      assert sources, "Missing #{directive} policy"
      assert_includes sources, "'self'"
      assert_not_includes sources, "https:"
      assert_not_includes sources, "http:"
    end
  end

  test "self-hosted subscription endpoints cannot contact Stripe" do
    Stripe::Customer.expects(:create).never
    Stripe::Checkout::Session.expects(:create).never
    Stripe::Checkout::Session.expects(:retrieve).never

    post account_subscription_path
    assert_response :not_found

    get account_subscription_path(session_id: "sess_123")
    assert_response :not_found
  end

  test "self-hosted billing portal cannot contact Stripe" do
    Stripe::BillingPortal::Session.expects(:create).never

    get account_billing_portal_path
    assert_response :not_found
  end

  test "self-hosted webhooks cannot contact Stripe" do
    Stripe::Webhook.expects(:construct_event).never
    Stripe::Subscription.expects(:retrieve).never
    Stripe::Invoice.expects(:create_preview).never

    untenanted { post stripe_webhooks_path, params: "{}", as: :json }
    assert_response :not_found
  end
end
