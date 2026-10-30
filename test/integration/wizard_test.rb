require "test_helper"

class WizardTest < ActionDispatch::IntegrationTest
  setup do
    stub_netpar_catalog
    @user = create_user
    sign_in @user
  end

  def wizard(proposal, step) = "/pl/proposals/#{proposal.multi_app_identifier}/wizard/#{step}"

  test "cały kreator: egzamin, dane, adres, opłata i załączniki, podsumowanie, wysłanie" do
    post "/pl/proposals"
    proposal = @user.proposals.last
    assert_redirected_to wizard(proposal, "step1")
    assert_equal "Testowy", proposal.name # dane z konta UKE

    get wizard(proposal, "step1"), params: { category: "R", division_id: 18 }
    assert_response :success
    assert_select "input[type=radio][name='proposal[exam_id]'][value='501']"

    patch wizard(proposal, "step1"), params: { proposal: { category: "R", division_id: 18, exam_id: 501 } }
    assert_redirected_to wizard(proposal, "step2")
    assert_equal [ "A", "R/1/2026" ], [ proposal.reload.division_short_name, proposal.exam_fullname.split(",").first ]

    patch wizard(proposal, "step2"), params: { proposal: { citizenship_code: "PL", birth_place: "Gdynia", birth_date: "1990-01-01", family_name: "Testowy" } }
    assert_redirected_to wizard(proposal, "step3")

    patch wizard(proposal, "step3"), params: { proposal: { lives_in_poland: "1", address_combine_id: teryt_address["combineId"], c_address_house: "1", c_address_postal_code: "81-323" } }
    assert_redirected_to wizard(proposal, "step4")
    assert_equal "Morska", proposal.reload.street_name

    get wizard(proposal, "step4")
    assert_select "dd", text: /75,00 PLN/
    patch wizard(proposal, "step4"), params: { proposal: { bank_pdf: fixture_file_upload("przelew.pdf", "application/pdf") } }
    assert_redirected_to wizard(proposal, "step5")

    get wizard(proposal, "step5")
    assert_select "a", text: "Zmień", count: 4
    netpar_post = stub_request(:post, "#{NETPAR_URL}/proposals").to_return(json({}, status: 201))
    patch wizard(proposal, "step5"), params: { proposal: { confirm_that_the_data_is_correct: "1" } }
    assert_redirected_to "/pl/proposals"
    assert_requested netpar_post
    assert proposal.reload.submitted?
  end

  test "kroków nie da się przeskoczyć" do
    proposal = draft_proposal(@user, status: "step1")
    get wizard(proposal, "step4")
    assert_redirected_to wizard(proposal, "step2")
  end

  test "sesja spoza listy NETPAR nie jest przyjmowana" do
    proposal = draft_proposal(@user)
    patch wizard(proposal, "step1"), params: { proposal: { category: "R", division_id: 18, exam_id: 999 } }
    assert_response :unprocessable_content
    assert_select ".error-summary", text: /Sesja egzaminacyjna nie może być puste/
  end

  test "NETPAR niedostępny: komunikat zamiast błędu" do
    proposal = draft_proposal(@user)
    stub_request(:get, "#{NETPAR_URL}/divisions").to_timeout
    get wizard(proposal, "step1"), params: { category: "R" }
    assert_response :service_unavailable
    assert_select ".flash--alert", text: /NETPAR jest chwilowo niedostępny/
  end

  test "NETPAR odrzuca zgłoszenie: czytelny komunikat, zgłoszenie do poprawy" do
    proposal = complete_proposal(@user, status: "step4")
    stub_request(:post, "#{NETPAR_URL}/proposals").to_return(json({ errors: { exam: [ "brak wolnych miejsc" ] } }, status: 422))
    patch wizard(proposal, "step5"), params: { proposal: { confirm_that_the_data_is_correct: "1" } }
    assert_response :unprocessable_content
    assert_select ".flash--alert", text: /nie zostało przyjęte przez system NETPAR: exam: brak wolnych miejsc/
  end

  test "cudze zgłoszenie – brak dostępu" do
    other = complete_proposal(create_user(email: "inny@example.com"))
    get wizard(other, "step1")
    assert_redirected_to "/pl/proposals"
    get "/pl/proposals/#{other.multi_app_identifier}"
    assert_redirected_to "/pl/proposals"
  end

  test "wysłanego zgłoszenia nie można edytować w kreatorze" do
    proposal = submitted_proposal(@user)
    get wizard(proposal, "step1")
    assert_redirected_to "/pl/proposals"
  end
end
