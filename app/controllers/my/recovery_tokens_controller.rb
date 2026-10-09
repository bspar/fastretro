class My::RecoveryTokensController < ApplicationController
  disallow_account_scope
  before_action :require_name_only_identity
  before_action :prevent_caching
  rate_limit to: 5, within: 1.hour, only: :create

  layout "auth"

  def show
    @recovery_token = session.delete(:name_only_recovery_token)
    @continue_url = after_authentication_url
  end

  def create
    Current.identity.with_lock do
      session[:name_only_recovery_token] = Current.identity.reset_recovery_token
      Current.identity.sessions.where.not(id: Current.session.id).destroy_all
    end
    redirect_to my_recovery_token_path(script_name: nil)
  end

  private
    def require_name_only_identity
      head :not_found unless FastRetro.name_only? && Current.identity.name_only?
    end

    def prevent_caching
      response.headers["Cache-Control"] = "no-store"
      response.headers["Referrer-Policy"] = "no-referrer"
    end
end
