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

  test "zgody RODO i historia zgłoszenia: tylko z tokenem; zgoda obowiązująca w chwili wysłania; nieznane zgłoszenie – 404" do
    user = @proposal.creator
    user.privacy_consents.create!(version: "2025-01", accepted_at: Time.zone.local(2025, 1, 10, 9, 0), ip: "10.0.0.1")
    user.privacy_consents.create!(version: "2026-10", accepted_at: Time.zone.local(2026, 10, 30, 12, 0), ip: "10.0.0.2")
    @proposal.update_columns(submitted_at: Time.zone.local(2026, 10, 1, 8, 0))
    @proposal.log_event("submitted", exam_id: 501, division_id: 18)
    @proposal.log_event("netpar_update", proposal_status_id: 2)

    get "/api/v1/proposals/#{@proposal.multi_app_identifier}"
    assert_response :unauthorized

    get "/api/v1/proposals/#{@proposal.multi_app_identifier}", headers: { "Authorization" => "Token token=#{token}" }
    assert_response :success
    body = response.parsed_body
    assert_equal @proposal.multi_app_identifier, body["multi_app_identifier"]
    assert_equal [ [ "2025-01", "10.0.0.1", true ], [ "2026-10", "10.0.0.2", false ] ],
                 body["privacy_consents"].map { it.values_at("version", "ip", "valid_at_submission") }
    assert_equal [ [ "submitted", "Zgłoszenie wysłane" ], [ "netpar_update", "Zmiana w systemie NETPAR" ] ],
                 body["events"].map { it.values_at("kind", "name") }
    assert_equal({ "proposal_status_id" => 2 }, body["events"].last["data"])
    assert_equal PrivacyConsent.current_version, body["privacy_current_version"]
    assert_not body.key?("pesel") # bez danych osobowych z formularza

    get "/api/v1/proposals/#{SecureRandom.uuid}", headers: { "Authorization" => "Token token=#{token}" }
    assert_response :not_found
  end
end
