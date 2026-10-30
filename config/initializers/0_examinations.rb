# Uzupełnia ustawienia z config/examinations.yml o dane zależne od serwera.
# Nazwa pliku zaczyna się od „0_”, bo inne inicjalizatory (np. devise.rb – adresy SAML) korzystają z tych ustawień.
# Kolejność: zmienna środowiskowa > credentials (config/credentials/<środowisko>.yml.enc) > config/examinations.yml.
#
# Struktura credentials (patrz README):
#   secret_key_base: …          # na produkcji TEN SAM co w poprzedniej wersji – podpisane linki do załączników
#   database: { host:, port:, name:, username:, password: }
#   host: egzaminy.uke.gov.pl   # adres aplikacji w mailach i linkach do załączników dla NETPAR
#   netpar: { url: https://…/api/v1, user: egzaminy, password: … }
#   teryt: { url: https://apiteryt.uke.gov.pl:443 }
#   saml: { callback_to:, idp_target_url:, issuer:, idp_cert_fingerprint:, idp_cert_fingerprint_algorithm: }
#   smtp: { address:, port:, user_name:, bcc:, password:, authentication:, starttls: }  # user_name – adres nadawcy
#   test_for_all_unlocked: false
#   redis, regulation – przeniesione z secrets.yml poprzedniej wersji, w examinations8 nieużywane
#   matomo: { enabled: false }  # opcjonalnie – np. serwer testowy bez statystyk
settings = Rails.configuration.x.examinations
credentials = Rails.application.credentials

setting = lambda do |path, env|
  ENV[env].presence || credentials.dig(*path) || settings.dig(*path)
end

settings[:netpar][:url] = setting.call(%i[netpar url], "NETPAR_URL")
settings[:netpar][:user] = setting.call(%i[netpar user], "NETPAR_USER")
settings[:netpar][:password] = setting.call(%i[netpar password], "NETPAR_PASSWORD")
settings[:teryt][:url] = setting.call(%i[teryt url], "TERYT_URL")
settings[:host] = setting.call(%i[host], "EXAMINATIONS_HOST")
settings[:saml] = %i[callback_to idp_target_url issuer idp_cert_fingerprint idp_cert_fingerprint_algorithm]
                    .to_h { [ it, setting.call([ :saml, it ], "SAML_#{it.upcase}") ] }
settings[:smtp] = %i[address port user_name password bcc authentication starttls].to_h { [ it, setting.call([ :smtp, it ], "SMTP_#{it.upcase}") ] }
unlocked = ENV["TEST_FOR_ALL_UNLOCKED"].presence || credentials[:test_for_all_unlocked]
settings[:test_for_all_unlocked] = ActiveModel::Type::Boolean.new.cast(unlocked) unless unlocked.nil?
matomo_enabled = ENV["MATOMO_ENABLED"].presence || credentials.dig(:matomo, :enabled)
settings[:matomo][:enabled] = ActiveModel::Type::Boolean.new.cast(matomo_enabled) unless matomo_enabled.nil?

# Bez kompletnych danych aplikacja nie startuje – zamiast po cichu łączyć się z niewłaściwą usługą.
# Pomijane w testach (WebMock) i przy budowaniu zasobów bez kluczy (SECRET_KEY_BASE_DUMMY).
unless Rails.env.test? || ENV["SECRET_KEY_BASE_DUMMY"].present?
  required = {
    "netpar.url" => settings.dig(:netpar, :url), "netpar.user" => settings.dig(:netpar, :user),
    "netpar.password" => settings.dig(:netpar, :password), "teryt.url" => settings.dig(:teryt, :url), "host" => settings[:host]
  }
  required.merge!(settings[:saml].transform_keys { "saml.#{it}" }) if Rails.env.production?
  required.merge!("smtp.address" => settings.dig(:smtp, :address)) if Rails.env.production?
  missing = required.select { |_, value| value.blank? }.keys
  if missing.any?
    raise "Brak ustawień: #{missing.join(", ")}. Uzupełnij config/credentials/#{Rails.env}.yml.enc " \
          "(bin/rails credentials:edit --environment #{Rails.env}) albo zmienne środowiskowe – patrz README."
  end
end
