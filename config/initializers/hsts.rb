# Nagłówek Strict-Transport-Security (HSTS) ustawia nginx dla wszystkich aplikacji na serwerze.
# Rails (force_ssl) dodawał drugi, z innym max-age – usuwamy go, zostawiając resztę force_ssl
# (przekierowanie na HTTPS, ciasteczka Secure).
#
# Nie używamy `config.ssl_options = { hsts: false }`: Rails wysłałby wtedy `max-age=0`, a przeglądarka
# bierze pod uwagę pierwszy nagłówek HSTS (RFC 6797) – to wyłączyłoby HSTS mimo nagłówka z nginx.
class RemoveRailsHsts
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)
    headers.delete(ActionDispatch::Constants::STRICT_TRANSPORT_SECURITY)
    [ status, headers, body ]
  end
end

# Przed ActionDispatch::SSL na liście = obejmuje go, więc widzi odpowiedź już z nagłówkiem HSTS.
if Rails.application.config.force_ssl
  Rails.application.config.middleware.insert_before ActionDispatch::SSL, RemoveRailsHsts
end
