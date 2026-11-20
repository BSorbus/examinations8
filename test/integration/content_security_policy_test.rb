require "test_helper"

# Content Security Policy (config/initializers/content_security_policy.rb) – raport bezpieczeństwa 2026-11-20, F-03.
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  HEADER = "Content-Security-Policy" # examinations.yml csp_report_only: false – polityka wymuszana

  def policy = response.headers[HEADER].to_s

  def nonce = policy[/'nonce-([^']+)'/, 1]

  test "polityka: własne zasoby, skrypty z nonce, TestPortal (ramka, formularz), CSU (wylogowanie), raport naruszeń" do
    get "/pl"
    assert_response :success
    assert_nil response.headers["Content-Security-Policy-Report-Only"], "polityka wymuszana, nie tylko raport"
    [ "default-src 'self'", "style-src 'self' 'unsafe-inline'", "img-src 'self' data:", "font-src 'self'", "connect-src 'self'",
      "frame-src 'self' https://egzaminyuke.testportal.pl", "object-src 'none'", "base-uri 'self'",
      "form-action 'self' https://egzaminyuke.testportal.pl https://idp.test", "frame-ancestors 'self'",
      "report-uri /csp-violation-report" ].each { assert_includes policy, it }
    assert_match(/script-src 'self' 'nonce-[^']+'/, policy)
    assert_no_match(/stats\.uke\.gov\.pl/, policy, "bez Matomo")
  end

  test "skrypty inline z nonce z polityki; nonce stały w sesji (Turbo nie przeładowuje dokumentu)" do
    sign_in create_user
    get "/pl"
    first = nonce
    assert first.present?
    assert_select "head script:not([src])" do |scripts|
      scripts.each { assert_equal first, it["nonce"], "skrypt inline bez nonce: #{it.to_html.truncate(80)}" }
    end
    get "/pl/proposals"
    assert_equal first, nonce
  end

  test "Matomo włączone: skrypt z nonce, domena statystyk w script-src, img-src i connect-src" do
    matomo = Rails.configuration.x.examinations[:matomo]
    previous, matomo[:enabled] = matomo[:enabled], true

    get "/pl"
    %w[script-src img-src connect-src].each { assert_match(/#{it} [^;]*https:\/\/stats\.uke\.gov\.pl/, policy) }
    assert_select "script[nonce='#{nonce}']", text: /_paq/
  ensure
    matomo[:enabled] = previous if matomo
  end

  test "raport naruszenia: wpis w logu bez parametrów adresu, bez logowania i tokenu CSRF" do
    log = StringIO.new
    previous, Rails.logger = Rails.logger, ActiveSupport::Logger.new(log)
    post "/csp-violation-report", params: { "csp-report" => {
      "document-uri" => "https://egzaminy.uke.gov.pl/pl/proposals/abc?pesel=90010100009",
      "violated-directive" => "frame-src", "blocked-uri" => "https://evil.example/x?token=1" } }.to_json,
      headers: { "Content-Type" => "application/csp-report" }
    assert_response :no_content
    entry = log.string.lines.grep(/\[CSP\]/)
    assert_equal 1, entry.size
    assert_includes entry.first, "[CSP] document-uri=https://egzaminy.uke.gov.pl/pl/proposals/abc violated-directive=frame-src"
    assert_no_match(/pesel|90010100009|token/, entry.first)

    post "/csp-violation-report", params: "nie json", headers: { "Content-Type" => "application/csp-report" }
    assert_response :bad_request
  ensure
    Rails.logger = previous if previous
  end
end
