source "https://rubygems.org"

gem "rails", "~> 8.1.4"
gem "propshaft"
gem "pg", "~> 1.7"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "rails-i18n", "~> 8.1"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false

# Logowanie przez konto UKE (WSO2, SAML) i uprawnienia
gem "devise", "~> 5.0"
gem "devise_saml_authenticatable", "~> 2.0"
gem "pundit", "~> 2.4"
# Skróty haseł kluczy API (has_secure_password)
gem "bcrypt", "~> 3.1"

# Kraj obywatelstwa (kody ISO jak w poprzedniej wersji)
gem "country_select", "~> 11.0"

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
  gem "mina", require: false
end

group :test do
  gem "webmock"
end
