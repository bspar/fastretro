class Signup
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  attr_accessor :full_name, :email_address, :identity
  attr_reader :account, :user, :recovery_token

  validates :email_address, format: { with: URI::MailTo::EMAIL_REGEXP }, on: :identity_creation
  validates :full_name, :identity, presence: true, on: :completion
  validates :full_name, presence: true, length: { maximum: 100 }, on: :name_only

  def initialize(...)
    super

    @email_address = @identity.email_address if @identity
  end

  def create_identity
    @identity = Identity.find_or_create_by!(email_address: email_address)
    @identity.send_magic_link for: :sign_up
  end

  def complete
    if valid?(:completion)
      begin
        create_account
        true
      rescue => error
        destroy_account
        handle_account_creation_error(error)

        errors.add(:base, "Something went wrong, and we couldn't create your account. Please give it another try.")
        Rails.error.report(error, severity: :error)
        Rails.logger.error error
        Rails.logger.error error.backtrace.join("\n")

        false
      end
    else
      false
    end
  end

  def create_name_only_account
    if valid?(:name_only)
      Identity.transaction do
        @identity = Identity.create_name_only!
        create_account
        @recovery_token = @identity.reset_recovery_token
      end
      true
    else
      false
    end
  end

  def join_by_name(join_code, identity: nil)
    @identity = identity

    if identity || valid?(:name_only)
      Identity.transaction do
        @identity ||= Identity.create_name_only!
        attributes = identity ? {} : { name: full_name, verified_at: Time.current }
        join_code.redeem_if { |account| @identity.join(account, **attributes) }
        @user = join_code.account.users.active.find_by!(identity: @identity)
        yield @user if block_given?
      end
      true
    else
      false
    end
  rescue ActiveRecord::RecordNotFound
    errors.add(:base, "This invite is no longer available.")
    false
  end

  private
    # Override to inject custom handling for account creation errors
    def handle_account_creation_error(error)
    end

    def create_account
      @account = Account.create_with_owner(
        account: {
          name: generate_account_name
        },
        owner: {
          name: full_name,
          identity: identity
        }
      )
      @user = @account.users.find_by!(role: :owner)
    end

    def generate_account_name
      "#{full_name}'s Team"
    end

    def destroy_account
      @account&.destroy!

      @user = nil
      @account = nil
    end
end
