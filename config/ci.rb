# Run using bin/ci

require_relative "../lib/fastretro"

OSS_ENV = "SAAS=false"
SAAS_ENV = "SAAS=true"
SYSTEM_TEST_ENV = "PARALLEL_WORKERS=1" # system tests can't run reliably in parallel

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Privacy: Self-hosted production", "env RAILS_ENV=production SAAS=false SECRET_KEY_BASE_DUMMY=1 ANALYTICS=true DISABLE_CSP=false SENTRY_DSN=https://public@example.invalid/1 STRIPE_SECRET_KEY=sk_test_inherited bin/rails runner script/check_self_hosted_privacy.rb"

  step "Security: Gem audit", "bin/bundler-audit check --update"
  step "Security: Importmap audit", "bin/importmap audit"
  step "Security: Brakeman audit", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error --skip-files fizzy/"
  step "Security: Gitleaks audit", "bin/gitleaks-audit"

  if FastRetro.saas?
    step "Tests: SaaS",        "#{SAAS_ENV} bin/rails test"
    step "Tests: SaaS System", "#{SAAS_ENV} #{SYSTEM_TEST_ENV} bin/rails test:system"
    step "Tests: OSS",         "#{OSS_ENV} bin/rails test"
    step "Tests: OSS System",  "#{OSS_ENV} #{SYSTEM_TEST_ENV} bin/rails test:system"
  else
    step "Tests: OSS",         "#{OSS_ENV} bin/rails test"
    step "Tests: OSS System",  "#{OSS_ENV} #{SYSTEM_TEST_ENV} bin/rails test:system"
  end

  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  step "Tests: JS", "npm ci --silent --no-audit --no-fund && npm test"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
