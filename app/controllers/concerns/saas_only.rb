module SaasOnly
  extend ActiveSupport::Concern

  included do
    before_action :require_saas
  end

  private
    def require_saas
      head :not_found unless FastRetro.saas?
    end
end
