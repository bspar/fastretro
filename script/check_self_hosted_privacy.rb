# Run with RAILS_ENV=production SAAS=false SECRET_KEY_BASE_DUMMY=1.
abort "This check requires production with SAAS=false" unless Rails.env.production? && !FastRetro.saas?

def check(condition, message)
  abort message unless condition
end

config = Rails.application.config
check(config.active_storage.service == :local, "Uploads must default to local storage")
check(ActiveStorage::Blob.service.is_a?(ActiveStorage::Service::DiskService), "The selected upload service must be local disk")
check(ApplicationController.helpers.analytics_tag.nil?, "Analytics must remain disabled")
check(Stripe.api_key.blank?, "Self-hosted mode must not initialize Stripe credentials")
check(!Sentry.initialized?, "Self-hosted mode must not initialize Sentry")
check(config.action_mailer.default_url_options[:host] != "fastretro.app", "Email links must not point to upstream")
check(!config.content_security_policy_report_only, "CSP must be enforced")

csp = config.content_security_policy
check(csp.present?, "CSP must not be disabled")
%w[ script-src connect-src img-src font-src media-src form-action ].each do |directive|
  sources = csp.directives.fetch(directive)
  check(!sources.include?("https:"), "#{directive} must not allow arbitrary remote hosts")
  check(sources.none? { |source| source.to_s.start_with?("http:", "https:") }, "#{directive} must default to local resources only")
end

puts "Self-hosted production defaults: local storage, no analytics/Stripe/Sentry, enforced local-resource CSP."
