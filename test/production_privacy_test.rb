require "test_helper"
require "open3"
require "rbconfig"

class ProductionPrivacyTest < ActiveSupport::TestCase
  test "production self-hosting stays local despite inherited telemetry credentials" do
    environment = {
      "RAILS_ENV" => "production", "SAAS" => "false", "SECRET_KEY_BASE_DUMMY" => "1",
      "ANALYTICS" => "true", "DISABLE_CSP" => "false", "SKIP_TELEMETRY" => nil,
      "SENTRY_DSN" => "https://public@example.invalid/1", "STRIPE_SECRET_KEY" => "sk_test_inherited",
      "ACTIVE_STORAGE_SERVICE" => nil, "APP_HOST" => nil, "DISABLE_SSL" => nil,
      "SMTP_ADDRESS" => "mailpit", "SMTP_USERNAME" => nil, "SMTP_PASSWORD" => nil, "SMTP_AUTHENTICATION" => nil
    }
    %w[ DEFAULT SCRIPT STYLE CONNECT FRAME IMG FONT MEDIA WORKER ].each do |directive|
      environment["CSP_#{directive}_SRC"] = nil
    end
    %w[ CSP_FRAME_ANCESTORS CSP_FORM_ACTION CSP_REPORT_URI CSP_REPORT_ONLY ].each { |setting| environment[setting] = nil }

    configurations = [
      { "DISABLE_SSL" => "false", "NAME_ONLY_AUTH" => nil },
      { "DISABLE_SSL" => "true", "NAME_ONLY_AUTH" => nil },
      { "DISABLE_SSL" => "true", "NAME_ONLY_AUTH" => "true", "SMTP_ADDRESS" => nil }
    ]
    configurations.each do |configuration|
      output, status = Open3.capture2e(environment.merge(configuration), RbConfig.ruby, "bin/rails", "runner", "script/check_self_hosted_privacy.rb", chdir: Rails.root.to_s)

      assert status.success?, output
      assert_includes output, "Self-hosted production defaults:"
    end
  end
end
