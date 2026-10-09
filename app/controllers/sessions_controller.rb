class SessionsController < ApplicationController
  include ActionPack::Passkey::Request

  disallow_account_scope
  require_unauthenticated_access except: :destroy
  rate_limit to: 10, within: 3.minutes, only: :create, with: :rate_limit_exceeded

  layout "auth"

  def new
    if FastRetro.name_only?
      render :name_only
    else
      @authentication_options = passkey_authentication_options
    end
  end

  def create
    if FastRetro.name_only?
      recover_by_token
    elsif identity = Identity.find_by_email_address(email_address)
      if identity.name_only?
        redirect_to_fake_session_magic_link email_address
      else
        sign_in identity
      end
    elsif Account.accepting_signups?
      sign_up
    else
      redirect_to_fake_session_magic_link email_address
    end
  end

  def destroy
    terminate_session
    redirect_to_logout_url
  end

  private
    def recover_by_token
      if identity = Identity.find_by_recovery_token(params.expect(:recovery_token).to_s.strip)
        start_new_session_for identity
        redirect_to after_authentication_url
      else
        flash.now[:alert] = "Invalid recovery token. Use your original browser or ask your facilitator for a new invite."
        render :name_only, status: :unprocessable_entity
      end
    end

    def sign_in(identity)
      redirect_to_session_magic_link identity.send_magic_link
    end

    def sign_up
      signup = Signup.new(email_address: email_address)

      if signup.valid?(:identity_creation)
        magic_link = signup.create_identity
        redirect_to_session_magic_link magic_link
      else
        head :unprocessable_entity
      end
    end

    def email_address
      params.expect(:email_address)
    end

    def rate_limit_exceeded
      redirect_to new_session_path, alert: t("flash.try_again_later")
    end
end
