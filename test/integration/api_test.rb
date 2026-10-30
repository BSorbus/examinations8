require "test_helper"

class ApiTest < ActionDispatch::IntegrationTest
  setup do
    @key = ApiKey.create!(name: "netpar2015", password: "tajne")
    @proposal = submitted_proposal(create_user)
  end

  def token
    get "/api/v1/token", headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("netpar2015", "tajne") }
    response.parsed_body["token"]
  end

  test "token tylko z poprawnym hasłem" do
    get "/api/v1/token", headers: { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("netpar2015", "złe") }
    assert_response :unauthorized
    assert token.present?
  end

  test "zmiana statusu w formacie NETPAR (Hash#to_s): zapis, historia, mail" do
    payload = { "id" => 7, "proposal_status_id" => 3, "not_approved_comment" => "Brak opłaty => uzupełnij", "name" => "Ignorowane" }.to_s
    assert_enqueued_emails 1 do
      patch "/api/v1/proposals/#{@proposal.multi_app_identifier}", params: { proposal: payload }, headers: { "Authorization" => "Token token=#{token}" }
    end
    assert_response :success
    @proposal.reload
    assert_equal [ 3, "Brak opłaty => uzupełnij", "Testowy" ], [ @proposal.proposal_status_id, @proposal.not_approved_comment, @proposal.name ]
    assert_equal({ "proposal_status_id" => 3, "not_approved_comment" => "Brak opłaty => uzupełnij" }, @proposal.events.last.data)
  end

  test "ta sama zmiana drugi raz: bez maila i bez wpisu w historii" do
    payload = { "proposal_status_id" => 2 }.to_s
    headers = { "Authorization" => "Token token=#{token}" }
    patch "/api/v1/proposals/#{@proposal.multi_app_identifier}", params: { proposal: payload }, headers: headers
    assert_no_enqueued_emails do
      patch "/api/v1/proposals/#{@proposal.multi_app_identifier}", params: { proposal: payload }, headers: headers
    end
    assert_equal 1, @proposal.events.count
  end

  test "zły token, brak zgłoszenia, złe dane" do
    patch "/api/v1/proposals/#{@proposal.multi_app_identifier}", params: { proposal: "{}" }, headers: { "Authorization" => "Token token=zły" }
    assert_response :unauthorized
    headers = { "Authorization" => "Token token=#{token}" }
    patch "/api/v1/proposals/brak", params: { proposal: "{}" }, headers: headers
    assert_response :not_found
    patch "/api/v1/proposals/#{@proposal.multi_app_identifier}", params: { proposal: "nie json" }, headers: headers
    assert_response :unprocessable_content
  end
end
