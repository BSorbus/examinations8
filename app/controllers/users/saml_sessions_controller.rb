# Logowanie kontem UKE (WSO2). Obsługa SAML (żądanie, odpowiedź, wylogowanie z IdP) – w gemie
# devise_saml_authenticatable; tu tylko adres po zalogowaniu.
class Users::SamlSessionsController < Devise::SamlSessionsController
  private
    def after_sign_in_path_for(resource) = stored_location_for(resource) || proposals_path
end
