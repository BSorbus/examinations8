# Logowanie kontem UKE (WSO2). Obsługa SAML (żądanie, odpowiedź, wylogowanie z IdP) – w gemie
# devise_saml_authenticatable; tu tylko adres po zalogowaniu i przekierowanie przy wylogowaniu.
class Users::SamlSessionsController < Devise::SamlSessionsController
  private
    def after_sign_in_path_for(resource) = stored_location_for(resource) || proposals_path

    # Wylogowanie kończy się w WSO2 (żądanie wylogowania SAML) – inny host niż aplikacja. Devise przekierowuje
    # bez allow_other_host, a Rails 7+ blokuje takie przekierowanie (OpenRedirectError). Adres pochodzi z naszej
    # konfiguracji (saml.idp_target_url), nie z parametrów żądania.
    def respond_to_on_destroy(non_navigational_status: :no_content)
      respond_to do |format|
        format.all { head non_navigational_status }
        format.any(*navigational_formats) do
          redirect_to after_sign_out_path_for(resource_name), status: Devise.responder.redirect_status, allow_other_host: true
        end
      end
    end
end
