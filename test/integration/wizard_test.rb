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
    assert_equal [ "", nil ], [ proposal.name, proposal.birth_date ] # dane osobowe – dopiero po zakładce 1

    get wizard(proposal, "step1"), params: { category: "R", division_id: 18 }
    assert_response :success
    assert_select "input[type=radio][name='proposal[exam_id]'][value='501']"

    patch wizard(proposal, "step1"), params: { proposal: { category: "R", division_id: 18, exam_id: 501 } }
    assert_redirected_to wizard(proposal, "step2")
    assert_equal [ "A", "R/1/2026" ], [ proposal.reload.division_short_name, proposal.exam_fullname.split(",").first ]
    assert_not proposal.division_face_image_required? # z NETPAR (division_a: face_image_required = false)
    assert_equal [ "", "", nil, "" ], [ proposal.name, proposal.email, proposal.birth_date, proposal.pesel ] # dane osobowe – jeszcze nie

    get wizard(proposal, "step2") # formularz podpowiada dane z konta UKE, bez zapisu
    assert_select "input[name='proposal[name]'][value='Testowy']"
    assert_select "input[name='proposal[pesel]'][value='90010100009']"
    assert_equal "", proposal.reload.name

    patch wizard(proposal, "step2"), params: { proposal: { pesel: "90010100009", citizenship_code: "PL", birth_place: "Gdynia", birth_date: "1990-01-01", family_name: "Testowy" } }
    assert_redirected_to wizard(proposal, "step3")
    assert_equal [ "Testowy", "Jan", "jan.testowy@example.com", Date.new(1990, 1, 1), "90010100009" ],
                 [ proposal.reload.name, proposal.given_names, proposal.email, proposal.birth_date, proposal.pesel ] # zapis po zakładce 2

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

  test "zakładka 1: podpowiedź o innych niedokończonych zgłoszeniach – zawężana wyborem służby i rodzaju" do
    empty = draft_proposal(@user)
    r_no_division = draft_proposal(@user, category: "R")
    r_a = draft_proposal(@user, category: "R", division_id: 18, division_short_name: "A", status: "step1")
    r_c = draft_proposal(@user, category: "R", division_id: 20, division_short_name: "C", status: "step1")
    m_lrc = draft_proposal(@user, category: "M", division_id: 13, division_short_name: "LRC", status: "step1")
    current = draft_proposal(@user)
    shown = -> { css_select(".other-drafts a.btn-primary").map { it["href"] } }
    links = ->(*proposals) { proposals.map { wizard(it, it.next_step) }.sort }

    get wizard(current, "step1") # nic nie wybrane – wszystkie
    assert_equal links.(empty, r_no_division, r_a, r_c, m_lrc), shown.().sort
    assert_select ".other-drafts li span", text: /– bez wybranej służby\z/
    assert_select ".other-drafts li span", text: /– Uprawnienia w służbie radioamatorskiej – bez wybranego rodzaju\z/

    get wizard(current, "step1"), params: { category: "R" } # służba R – bez służby i wszystkie R
    assert_equal links.(empty, r_no_division, r_a, r_c), shown.().sort

    get wizard(current, "step1"), params: { category: "R", division_id: 18 } # R, klasa A – bez służby, R bez rodzaju, R A
    assert_equal links.(empty, r_no_division, r_a), shown.().sort
    assert_select ".other-drafts p", text: /Masz już 3 inne niedokończone zgłoszenia/

    patch wizard(current, "step1"), params: { proposal: { category: "R", division_id: 18, exam_id: 501 } }
    assert_redirected_to wizard(current, "step2") # podpowiedź nie blokuje
  end

  test "zakładka 1: „Usuń je” usuwa wcześniejsze zgłoszenie i wraca do bieżącego" do
    old = draft_proposal(@user, category: "R", division_id: 18, division_short_name: "A", status: "step1")
    current = draft_proposal(@user)

    delete "/pl/proposals/#{old.multi_app_identifier}", params: { return_to: current.multi_app_identifier }
    assert_redirected_to wizard(current, "step1")
    assert_not Proposal.exists?(old.id)

    get wizard(current, "step1")
    assert_select ".other-drafts", count: 0
  end

  test "zakładka 1: zgłoszenie w toku na ten rodzaj w NETPAR – błąd; w NETPAR zamknięte – można dalej" do
    proposal = draft_proposal(@user)
    stub_netpar_proposals([ { "multi_app_identifier" => SecureRandom.uuid, "division_id" => 18, "proposal_status_id" => 2 } ])
    patch wizard(proposal, "step1"), params: { proposal: { category: "R", division_id: 18, exam_id: 501 } }
    assert_response :unprocessable_content
    assert_select ".error-summary", text: /Jest aktualnie procedowane Twoje zgłoszenie dla tego typu świadectwa/

    stub_netpar_proposals([ { "multi_app_identifier" => SecureRandom.uuid, "division_id" => 18, "proposal_status_id" => 4 } ])
    patch wizard(proposal, "step1"), params: { proposal: { category: "R", division_id: 18, exam_id: 501 } }
    assert_redirected_to wizard(proposal, "step2")
  end

  test "wysłanie: NETPAR odrzuca drugie zgłoszenie w toku na ten rodzaj – komunikat, zgłoszenie do poprawy" do
    proposal = complete_proposal(@user)
    proposal.update_columns(status: "step4")
    stub_request(:post, "#{NETPAR_URL}/proposals")
      .to_return(json({ errors: [ "Jest aktualnie procedowane zgłoszenie dla tego typu świadectwa" ] }, status: 422))
    patch wizard(proposal, "step5"), params: { proposal: { confirm_that_the_data_is_correct: "1" } }
    assert_response :unprocessable_content
    assert_match "Jest aktualnie procedowane zgłoszenie dla tego typu świadectwa", response.body
    assert_not proposal.reload.submitted?
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
