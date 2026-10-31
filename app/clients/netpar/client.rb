require "net/http"

module Netpar
  # Klient API NETPAR dla zgłoszeń na egzamin.
  #
  # Kontrakt API (po stronie NETPAR, Api::V1):
  #   GET    /token                                    Basic Auth → {"token": "…"}
  #   GET    /divisions {enabled_in_examination: true, category:}  rodzaje dla zapisów przez internet
  #   GET    /divisions/:id                            rodzaj (m.in. fullname, short_name, min_years_old)
  #   GET    /exams {category:, division_id:, q:, page:, page_limit:}  sesje z wolnymi miejscami
  #   GET    /exams/:id                                sesja (m.in. fullname, date_exam, online)
  #   GET    /exam_fees/find {division_id:, esod_category:, for_date:}  opłata (price, price_under18)
  #   POST   /proposals          proposal=<JSON>       nowe zgłoszenie → 201 (422 – odrzucone)
  #   PATCH  /proposals/:multi_app_identifier          zmiana zgłoszenia (np. anulowanie) → 200 (404 – brak w NETPAR)
  # Wysyłanie zgłoszenia jest idempotentne po naszej stronie (ProposalSubmission: przy ponowieniu najpierw PATCH).
  #   GET    /proposals/:multi_app_identifier/grades               testy egzaminu online (TestPortal)
  #   GET    /proposals/:multi_app_identifier/grades_with_result   wyniki testów
  # Zapytania GET wysyłają parametry jako treść JSON (tak czyta je NETPAR), nagłówek "Authorization: Token token=…".
  # NETPAR odczytuje parametr "proposal" przez JSON.parse(proposal.gsub("=>", ":")) – wysyłamy czysty JSON.
  class Client
    TOKEN_CACHE_KEY = "netpar/token"
    TOKEN_TTL = 9.minutes
    ALL = 1000 # „wszystkie” w API ze stronicowaniem

    def initialize(config: Rails.configuration.x.examinations[:netpar], cache: Rails.cache)
      @base_url = config.fetch(:url).chomp("/")
      @user = config.fetch(:user)
      @password = config[:password]
      @open_timeout = config.fetch(:open_timeout)
      @read_timeout = config.fetch(:read_timeout)
      @cache = cache
    end

    def divisions(category:)
      fetch_json(:get, "divisions", body: { enabled_in_examination: true, category: }, expect: "divisions")
    end

    def division(id) = find("divisions/#{id.to_i}")

    def exams(category:, division_id:)
      fetch_json(:get, "exams", body: { category:, division_id:, q: "", page: 1, page_limit: ALL }, expect: "exams")
    end

    def exam(id) = find("exams/#{id.to_i}")

    def exam_fee(division_id:, esod_category:, for_date:)
      response = request(:get, "exam_fees/find", body: { division_id:, esod_category:, for_date: for_date.to_s })
      response.is_a?(Net::HTTPNotFound) ? nil : parse(response, expect: "id", whole: true)
    end

    def create_proposal(attributes)
      response = request(:post, "proposals", form: { proposal: attributes.to_json })
      ensure_success!(response, Net::HTTPCreated, Net::HTTPOK)
    end

    # true – zmienione, false – NETPAR nie ma takiego zgłoszenia (404).
    def update_proposal(multi_app_identifier, attributes)
      response = request(:patch, "proposals/#{multi_app_identifier}", form: { proposal: attributes.to_json })
      return false if response.is_a?(Net::HTTPNotFound)

      ensure_success!(response, Net::HTTPOK)
    end

    # Testy egzaminu online (pusta lista, gdy NETPAR nie ma jeszcze egzaminu dla zgłoszenia).
    def grades(multi_app_identifier)
      grades_list("proposals/#{multi_app_identifier}/grades", "grades")
    end

    def grades_with_result(multi_app_identifier)
      grades_list("proposals/#{multi_app_identifier}/grades_with_result", "grades_with_result")
    end

    private
      def find(path)
        response = request(:get, path)
        response.is_a?(Net::HTTPNotFound) ? nil : parse(response, expect: "id", whole: true)
      end

      def fetch_json(method, path, body:, expect:)
        parse(request(method, path, body:), expect:)
      end

      def grades_list(path, key)
        response = request(:get, path)
        response.is_a?(Net::HTTPNotFound) ? [] : parse(response, expect: key)
      end

      def ensure_success!(response, *success)
        return true if success.any? { response.is_a?(it) }
        raise Rejected, rejection_messages(response) if response.is_a?(Net::HTTPUnprocessableEntity)

        raise Unavailable, "NETPAR #{response.uri&.path}: HTTP #{response.code} #{response.body.to_s.truncate(300)}"
      end

      # Zapytanie z tokenem; wygasły token (401) – pobranie nowego i ponowienie.
      def request(method, path, body: nil, form: nil)
        response = perform(build(method, path, token:, body:, form:))
        return response unless response.is_a?(Net::HTTPUnauthorized)

        @cache.delete(TOKEN_CACHE_KEY)
        perform(build(method, path, token:, body:, form:))
      end

      def build(method, path, token:, body:, form:)
        request = Net::HTTP.const_get(method.to_s.capitalize).new(uri(path), "Authorization" => "Token token=#{token}")
        if form
          request.set_form_data(form)
        else
          request["Content-Type"] = "application/json"
          request.body = body.to_json if body
        end
        request
      end

      def token
        @cache.fetch(TOKEN_CACHE_KEY, expires_in: TOKEN_TTL) do
          request = Net::HTTP::Get.new(uri("token"))
          request.basic_auth(@user, @password)
          response = perform(request)
          raise Unavailable, "NETPAR /token: HTTP #{response.code}" unless response.is_a?(Net::HTTPOK)

          parse(response, expect: "token")
        end
      end

      def perform(request)
        target = request.uri
        Net::HTTP.start(target.host, target.port, use_ssl: target.scheme == "https",
                        open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
          http.request(request)
        end
      rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError, IOError => e
        raise Unavailable, "NETPAR: #{e.class}: #{e.message}"
      end

      # Wartość klucza `expect` z odpowiedzi JSON (albo cały obiekt przy whole: true);
      # każda inna odpowiedź oznacza niedostępność usługi.
      def parse(response, expect:, whole: false)
        raise Unavailable, "NETPAR #{response.uri&.path}: HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body.to_s)
        raise Unavailable, "NETPAR: brak klucza #{expect} w odpowiedzi" unless data.is_a?(Hash) && data.key?(expect)

        whole ? data : data[expect]
      rescue JSON::ParserError
        raise Unavailable, "NETPAR: odpowiedź nie jest JSON-em (HTTP #{response.code})"
      end

      # {"errors": {"exam": ["…"]}} → ["exam: …"]
      def rejection_messages(response)
        errors = JSON.parse(response.body.to_s)["errors"]
        errors.is_a?(Hash) ? errors.flat_map { |field, messages| Array(messages).map { "#{field}: #{it}" } } : Array(errors)
      rescue JSON::ParserError, TypeError
        [ response.body.to_s.truncate(200) ]
      end

      def uri(path) = URI("#{@base_url}/#{path}")
  end
end
