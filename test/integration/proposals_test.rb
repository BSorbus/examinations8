require "test_helper"

class ProposalsTest < ActionDispatch::IntegrationTest
  setup do
    stub_netpar_token
    @user = create_user
  end

  test "lista wymaga zalogowania" do
    get "/pl/proposals"
    assert_redirected_to "/users/saml/sign_in"
  end

  test "lista: wysłane i niedokończone" do
    sign_in @user
    submitted_proposal(@user)
    draft_proposal(@user, status: "step2")
    get "/pl/proposals"
    assert_select "#drafts_heading"
    assert_select "a", text: "Dokończ"
    assert_select ".status", text: "Zgłoszenie utworzone"
  end

  test "unieważnienie: NETPAR, status, historia" do
    sign_in @user
    proposal = submitted_proposal(@user)
    patch_request = stub_request(:patch, "#{NETPAR_URL}/proposals/#{proposal.multi_app_identifier}").to_return(json({}))
    patch "/pl/proposals/#{proposal.multi_app_identifier}/annul"
    assert_requested patch_request.with { URI.decode_www_form(it.body).to_h["proposal"].include?('"proposal_status_id":5') }
    assert_equal 5, proposal.reload.proposal_status_id
    assert_equal [ "annulled" ], proposal.events.pluck(:kind)
  end

  test "unieważnienie przy błędzie NETPAR – bez zmian u nas" do
    sign_in @user
    proposal = submitted_proposal(@user)
    stub_request(:patch, "#{NETPAR_URL}/proposals/#{proposal.multi_app_identifier}").to_return(status: 500)
    patch "/pl/proposals/#{proposal.multi_app_identifier}/annul"
    assert_equal "System NETPAR jest chwilowo niedostępny. Spróbuj ponownie za kilka minut.", flash[:alert]
    assert_equal 1, proposal.reload.proposal_status_id
    assert_empty proposal.events
  end

  test "egzamin poprawkowy: nowe zgłoszenie z rodzajem i adresem z poprzedniego" do
    sign_in @user
    proposal = submitted_proposal(@user, proposal_status_id: Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N)
    post "/pl/proposals/#{proposal.multi_app_identifier}/correction_exam"
    correction = @user.proposals.order(:id).last
    assert_equal [ 42, 18, "81-323" ], [ correction.esod_category, correction.division_id, correction.c_address_postal_code ]
  end

  test "egzamin online: testy z NETPAR, formularz TestPortal" do
    sign_in @user
    proposal = submitted_proposal(@user, proposal_status_id: 2, exam_online: true, test_unlocked: true)
    stub_request(:get, "#{NETPAR_URL}/proposals/#{proposal.multi_app_identifier}/grades")
      .to_return(json({ grades: [ { "testportal_access_code_id" => "KOD1", "subject_name" => "Przepisy", "testportal_test_info" => { "name" => "Test 1" } } ] }))
    get "/pl/proposals/#{proposal.multi_app_identifier}/testportal"
    assert_response :success
    assert_select "form[action='https://egzaminyuke.testportal.pl/exam/start.html'][target=test-frame] button", text: "Test 1"
    start = JSON.parse(css_select("input[name=startTestRequest]").first["value"])
    assert_equal [ "KOD1", proposal.multi_app_identifier ], start.values_at("accessCode", "personUID")
  end

  test "podpowiedzi adresów tylko dla zalogowanych" do
    get "/pl/lookups/addresses", params: { q: "gdynia" }
    assert_response :redirect
    sign_in @user
    get "/pl/lookups/addresses", params: { q: "gd" }
    assert_equal({ "total" => 0, "items" => [] }, response.parsed_body)
  end
end
