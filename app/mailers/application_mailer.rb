class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "FastRetro <noreply@localhost>")

  before_action :require_production_mail_settings
  after_action :disable_name_only_delivery

  layout "mailer"
  append_view_path Rails.root.join("app/views/mailers")

  private
    def require_production_mail_settings
      if Rails.env.production? && !FastRetro.name_only?
        %w[ APP_HOST MAILER_FROM_ADDRESS SMTP_ADDRESS ].each do |setting|
          raise ArgumentError, "#{setting} must be configured before sending production email" if ENV[setting].blank?
        end
      end
    end

    def disable_name_only_delivery
      if FastRetro.name_only? || mail.destinations.any? { |address| address.end_with?("@name-only.invalid") }
        mail.perform_deliveries = false
      end
    end

    def default_url_options
      if Current.account
        super.merge(script_name: Current.account.slug)
      else
        super
      end
    end
end
