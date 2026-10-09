require "digest"

module Identity::NameOnlyAuthenticatable
  extend ActiveSupport::Concern

  class_methods do
    def create_name_only!
      create!(name_only: true, email_address: "#{SecureRandom.uuid}@name-only.invalid")
    end

    def find_by_recovery_token(token)
      if token.match?(/\Afr_[a-zA-Z0-9]{43}\z/)
        find_by(name_only: true, recovery_token_digest: Digest::SHA256.hexdigest(token))
      end
    end
  end

  def reset_recovery_token
    raise ArgumentError, "Only name-only identities use recovery tokens" unless name_only?

    token = "fr_#{SecureRandom.base58(43)}"
    update!(recovery_token_digest: Digest::SHA256.hexdigest(token))
    token
  end
end
