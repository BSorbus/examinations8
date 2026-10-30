require "net/http"

module Teryt
  # Klient API adresów TERYT (apiteryt.uke.gov.pl):
  #   GET /Address?Query=&Offset=&Limit=&Order=name&OrderDir=asc  → {"total": n, "items": […]}
  #   GET /Address/:combineId                                      → adres (provinceName, cityName, streetName, postCode…)
  class Client
    def initialize(config: Rails.configuration.x.examinations[:teryt])
      @base_url = config.fetch(:url).chomp("/")
      @open_timeout = config.fetch(:open_timeout)
      @read_timeout = config.fetch(:read_timeout)
    end

    def addresses(query, page: 1, limit: 20)
      uri = URI("#{@base_url}/Address")
      uri.query = URI.encode_www_form(Query: query, Offset: page, Limit: limit, Order: "name", OrderDir: "asc")
      data = get(uri)
      raise Unavailable, "TERYT: niepoprawna lista adresów" unless data.is_a?(Hash) && data["items"].is_a?(Array)

      data
    end

    def address(combine_id)
      return if combine_id.blank?

      get(URI("#{@base_url}/Address/#{ERB::Util.url_encode(combine_id)}"))
    end

    private
      def get(uri)
        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                   open_timeout: @open_timeout, read_timeout: @read_timeout) do |http|
          http.request(Net::HTTP::Get.new(uri, "Accept" => "application/json"))
        end
        return if response.is_a?(Net::HTTPNotFound)
        raise Unavailable, "TERYT: HTTP #{response.code}" unless response.is_a?(Net::HTTPOK)

        JSON.parse(response.body.to_s)
      rescue SocketError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, EOFError, IOError => e
        raise Unavailable, "TERYT: #{e.class}: #{e.message}"
      rescue JSON::ParserError
        raise Unavailable, "TERYT: odpowiedź nie jest JSON-em"
      end
  end
end
