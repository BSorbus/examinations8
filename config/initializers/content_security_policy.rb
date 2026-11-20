# Content Security Policy (raport bezpieczeństwa 2026-11-20, F-03; jak w confirmation8) – polityka w aplikacji zamiast
# szczątkowej w nginx.
#
# - skrypty: tylko z naszego serwera i skrypty inline z nonce (motyw strony w layoucie, Matomo; importmap dodaje nonce
#   sam). Nonce stały w obrębie sesji: Turbo podmienia strony bez przeładowania dokumentu, a polityka obowiązuje
#   z pierwszego wczytania – nowy nonce przy każdej odpowiedzi blokowałby skrypty;
# - style: z naszego serwera i 'unsafe-inline' (styl paska postępu Turbo); style nie wykonują kodu;
# - obrazy: także data: (strzałki pól wyboru w Bootstrapie);
# - TestPortal (testportal_start_url): egzamin online w ramce (frame-src) uruchamiany formularzem POST (form-action);
# - CSU (saml.idp_target_url): wylogowanie to formularz, po którym serwer przekierowuje do WSO2 – form-action obejmuje
#   także przekierowania po wysłaniu formularza;
# - Matomo (gdy włączone): skrypt, zapytania i piksel ze stats.uke.gov.pl;
# - naruszenia zgłaszane na /csp-violation-report (CspReportsController – wpis w logu).
# Adresy liczone przy każdym żądaniu z bieżącej konfiguracji. Tryb: examinations.yml csp_report_only (true – tylko
# raport, nic nie blokuje; po sprawdzeniu – false).
Rails.application.configure do
  origin = ->(url) { URI(url).then { "#{it.scheme}://#{it.host}#{":#{it.port}" unless it.port == it.default_port}" } if url.present? }
  settings = -> { Rails.configuration.x.examinations }
  matomo_host = -> { origin.(settings.()[:matomo][:url]) if settings.()[:matomo][:enabled] }
  testportal_host = -> { origin.(settings.()[:testportal_start_url]) }
  csu_host = -> { origin.(settings.()[:saml][:idp_target_url]) }

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src :self, matomo_host
    policy.style_src :self, :unsafe_inline
    policy.img_src :self, :data, matomo_host
    policy.font_src :self
    policy.connect_src :self, matomo_host
    policy.frame_src :self, testportal_host
    policy.object_src :none
    policy.base_uri :self
    policy.form_action :self, testportal_host, csu_host
    policy.frame_ancestors :self
    policy.upgrade_insecure_requests true if Rails.env.production?
    policy.report_uri "/csp-violation-report"
  end

  config.content_security_policy_nonce_generator = ->(request) { request.session[:csp_nonce] ||= SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_report_only = config.x.examinations.fetch(:csp_report_only, true)
end
