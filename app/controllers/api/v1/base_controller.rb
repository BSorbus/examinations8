# API dla NETPAR. Token: GET /api/v1/token z Basic Auth (klucz api_keys), dalej "Authorization: Token token=…".
class Api::V1::BaseController < ActionController::API
  include ActionController::HttpAuthentication::Basic::ControllerMethods
  include ActionController::HttpAuthentication::Token::ControllerMethods

  before_action :authenticate_api_key!, except: :token
  rate_limit to: 60, within: 1.minute, only: :token

  def token
    key = authenticate_with_http_basic { |name, password| ApiKey.authenticate(name, password) }
    if key
      render json: { token: key.issue_token }
    else
      render json: { error: "Incorrect credentials" }, status: :unauthorized
    end
  end

  private
    def authenticate_api_key!
      @api_key = authenticate_with_http_token { |token, _options| ApiKey.find_by_token(token) }
      render json: { error: "Bad Token" }, status: :unauthorized unless @api_key
    end
end
