class ApplicationController < ActionController::Base
  include Pundit::Authorization

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action { I18n.locale = I18n.default_locale }
  # Bez akceptacji informacji o przetwarzaniu danych osobowych (RODO) – tylko strona zgody i wylogowanie.
  before_action :require_privacy_consent, if: :user_signed_in?, unless: :devise_controller?

  rescue_from Pundit::NotAuthorizedError do
    redirect_to proposals_path, alert: t("pundit.default")
  end

  private
    def after_sign_in_path_for(resource) = stored_location_for(resource) || proposals_path

    def netpar = Netpar::Client.new

    def require_privacy_consent
      return if current_user.privacy_accepted?

      store_location_for(:user, request.fullpath) if request.get? && request.format.html?
      redirect_to privacy_consent_path
    end
end
