# Zgłoszenia naruszeń Content Security Policy wysyłane przez przeglądarki (report-uri) – tylko wpis w logu, żeby po
# wdrożeniu w trybie Report-Only zobaczyć, co polityka zablokowałaby po włączeniu. Bez parametrów adresów (mogą nieść
# dane) i z ograniczoną długością pól. ActionController::API – bez sesji i tokenu CSRF
# (przeglądarki wysyłają raport bez niego).
class CspReportsController < ActionController::API
  rate_limit to: 30, within: 1.minute

  FIELDS = %w[document-uri violated-directive effective-directive blocked-uri source-file line-number disposition].freeze

  def create
    report = JSON.parse(request.raw_post.to_s.byteslice(0, 8_000)).fetch("csp-report", {})
    details = FIELDS.filter_map do |field|
      value = report[field].to_s.split("?").first.to_s.truncate(200)
      "#{field}=#{value}" if value.present?
    end
    Rails.logger.warn("[CSP] #{details.join(' ')}")
    head :no_content
  rescue JSON::ParserError, TypeError
    head :bad_request
  end
end
