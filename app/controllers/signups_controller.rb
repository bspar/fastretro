class SignupsController < ApplicationController
  disallow_account_scope
  allow_unauthenticated_access
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_signup_path, alert: t("flash.try_again_later") }
  before_action :redirect_authenticated_user
  before_action :enforce_tenant_limit

  layout "auth"

  def new
    @signup = Signup.new
    render :name_only if FastRetro.name_only?
  end

  def create
    if FastRetro.name_only?
      create_by_name
    else
      signup = Signup.new(signup_params)
      if signup.valid?(:identity_creation)
        redirect_to_session_magic_link signup.create_identity
      else
        head :unprocessable_entity
      end
    end
  end

  private
    def create_by_name
      @signup = Signup.new(full_name: params.expect(signup: :full_name).fetch(:full_name).to_s.strip)

      if @signup.create_name_only_account
        start_new_session_for @signup.identity
        session[:return_to_after_authenticating] = landing_url(script_name: @signup.account.slug)
        session[:name_only_recovery_token] = @signup.recovery_token
        redirect_to my_recovery_token_path(script_name: nil)
      else
        render :name_only, status: :unprocessable_entity
      end
    end

    def redirect_authenticated_user
      if authenticated?
        redirect_to FastRetro.name_only? ? session_menu_path : new_signup_completion_path
      end
    end

    def enforce_tenant_limit
      redirect_to new_session_url unless Account.accepting_signups?
    end

    def signup_params
      params.expect signup: :email_address
    end
end
