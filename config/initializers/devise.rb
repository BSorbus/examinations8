# Logowanie wyłącznie przez konto UKE (WSO2, SAML) – jak w poprzedniej wersji.
# Adresy i odcisk certyfikatu IdP: credentials (saml.*) – patrz config/initializers/examinations.rb.
require "devise/orm/active_record"

Devise.setup do |config|
  config.mailer_sender = "no-reply@uke.gov.pl"
  config.authentication_keys = [ :email ]
  config.case_insensitive_keys = [ :email ]
  config.strip_whitespace_keys = [ :email ]
  config.skip_session_storage = [ :http_auth ]
  config.sign_out_via = :delete
  config.responder.error_status = :unprocessable_content
  config.responder.redirect_status = :see_other

  # Użytkownik zakładany i aktualizowany na podstawie danych z konta UKE.
  config.saml_create_user = true
  config.saml_update_user = true
  config.saml_default_user_key = :email
  config.saml_session_index_key = :session_index
  config.saml_use_subject = true
  config.idp_settings_adapter = nil

  config.saml_configure do |settings|
    saml = Rails.configuration.x.examinations[:saml]
    # Adres aplikacji zarejestrowany w WSO2 (dawne idp_callback_to); bez niego – https://<host>.
    callback = saml[:callback_to].presence || "https://#{Rails.configuration.x.examinations[:host]}"

    settings.assertion_consumer_service_url = "#{callback}/users/saml/auth"
    settings.assertion_consumer_service_binding = "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
    settings.name_identifier_format = "urn:oasis:names:tc:SAML:2.0:nameid-format:transient"
    settings.issuer = saml[:issuer]
    settings.idp_sso_service_url = "#{saml[:idp_target_url]}/samlsso"
    settings.idp_slo_service_url = "#{saml[:idp_target_url]}/samlsso?slo=true&spEntityID=#{saml[:issuer]}&returnTo=#{callback}"
    settings.idp_cert_fingerprint = saml[:idp_cert_fingerprint]
    settings.idp_cert_fingerprint_algorithm = saml[:idp_cert_fingerprint_algorithm]
  end
end
