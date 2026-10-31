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

    patch wizard(proposal, "step3"), params: { proposal: { lives_in_poland: "1", address_combine_id: teryt_address["combineId"], c_address_house: "1", c_address_postal_code: "00-000" } }
    assert_redirected_to wizard(proposal, "step4")
    assert_equal [ "Morska", "81-323" ], [ proposal.reload.street_name, proposal.c_address_postal_code ] # kod z wybranej pozycji TERYT

    get wizard(proposal, "step4")
    assert_select "dd", text: /75,00 PLN/
    assert_select "dd", text: /za przeprowadzenie egzaminu w służbie radiokomunikacyjnej amatorskiej/ # tytuł przelewu wg służby (R)
    patch wizard(proposal, "step4"), params: { proposal: { bank_pdf: fixture_file_upload("przelew.pdf", "application/pdf") } }
    assert_redirected_to wizard(proposal, "step5")

    get wizard(proposal, "step5")
    assert_select "a", text: "Zmień", count: 4
    assert_select ".confirm-box input[name='proposal[confirm_that_the_data_is_correct]']" # potwierdzenie w wyraźnej ramce
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

  test "zakładka 1: rodzaj wniosku z prawa do poprawki w NETPAR – zwykły szkic na ten rodzaj staje się poprawkowym" do
    failed = submitted_proposal(@user, proposal_status_id: Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N)
    stub_netpar_proposals([ netpar_failed_row(failed) ])
    current = draft_proposal(@user)

    get wizard(current, "step1"), params: { category: "R", division_id: 18 }
    assert_select ".correction-box[role=status] .correction-box__title", text: "Wniosek o przeprowadzenie egzaminu poprawkowego"
    assert_select ".correction-box p", text: /Masz prawo do egzaminu poprawkowego/
    assert_select ".wizard-correction", count: 0 # na zakładce 1 tylko ramka z wyjaśnieniem
    get wizard(current, "step1"), params: { category: "R" } # bez rodzaju – zwykły wniosek, bez ramki
    assert_select ".correction-box", count: 0

    patch wizard(current, "step1"), params: { proposal: { category: "R", division_id: 18, exam_id: 501 } }
    assert_redirected_to wizard(current, "step2")
    assert_equal Proposal::ESOD_CATEGORY_POPRAWKOWY, current.reload.esod_category
    follow_redirect!
    assert_select ".wizard-correction", text: "Wniosek o przeprowadzenie egzaminu poprawkowego" # pod paskiem kroków na kolejnych zakładkach
  end

  test "zakładka 4: egzamin poprawkowy – dopisek przy kwocie i tytuł przelewu; zwykły egzamin – bez zmian" do
    failed = submitted_proposal(@user, proposal_status_id: Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N)
    stub_netpar_proposals([ netpar_failed_row(failed) ])
    correction = complete_proposal(@user, esod_category: Proposal::ESOD_CATEGORY_POPRAWKOWY, exam_fee_id: 10, exam_fee_price: 50)
    correction.update_columns(status: "step3")
    get wizard(correction, "step4")
    assert_select ".payment dd", text: /\(egzamin poprawkowy\)/
    assert_select ".payment dd", text: /za przeprowadzenie egzaminu poprawkowego w służbie radiokomunikacyjnej amatorskiej/
    assert_select ".wizard-correction", count: 1

    stub_netpar_proposals # bez prawa do poprawki
    exam = complete_proposal(@user, exam_fee_id: 10, exam_fee_price: 75)
    exam.update_columns(status: "step3")
    get wizard(exam, "step4")
    assert_select ".payment dd", text: /za przeprowadzenie egzaminu w służbie radiokomunikacyjnej amatorskiej/
    assert_select ".payment dd", text: /poprawkow/, count: 0
    assert_select ".wizard-correction", count: 0
  end

  test "zakładka 1: sesja po terminie poprawki (rok od oblanej sesji) – zwykły egzamin z informacją o terminie" do
    failed = submitted_proposal(@user, proposal_status_id: Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N)
    deadline = Time.zone.today + 10 # sesja szkicu: za 30 dni
    stub_netpar_proposals([ netpar_failed_row(failed, exam_date: deadline - 1.year) ])
    draft = complete_proposal(@user)
    draft.update_columns(status: "step1")

    get wizard(draft, "step1")
    assert_select ".correction-box__title", count: 0
    assert_select ".correction-box p", text: /obejmuje sesje najpóźniej do #{deadline.strftime('%d.%m.%Y')}\. Wybrana sesja jest późniejsza/
    assert_equal Proposal::ESOD_CATEGORY_EGZAMIN, draft.reload.esod_category
  end

  test "wysłanie: prawo do poprawki zmieniło się od zakładki 1 – rodzaj wniosku poprawiony, powrót do opłaty, nic do NETPAR" do
    proposal = complete_proposal(@user)
    proposal.update_columns(status: "step4")
    failed = submitted_proposal(@user, proposal_status_id: Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N)
    stub_netpar_proposals([ netpar_failed_row(failed) ])

    patch wizard(proposal, "step5"), params: { proposal: { confirm_that_the_data_is_correct: "1" } }
    assert_response :unprocessable_content
    assert_select ".error-summary, [role=alert]", text: /wróć do zakładki 4/
    assert_equal [ 42, nil, "step3" ], proposal.reload.values_at(:esod_category, :exam_fee_id, :status)
    assert_not_requested :post, "#{NETPAR_URL}/proposals"
  end

  test "powrót do porzuconego szkicu po wyniku z prawem do poprawki: zakładka 4 od nowa, kreator od zakładki 4" do
    abandoned = complete_proposal(@user, exam_fee_id: 7, exam_fee_price: 75)
    abandoned.update_columns(status: "step4", confirm_that_the_data_is_correct: true) # doszedł do podsumowania
    failed = submitted_proposal(@user, proposal_status_id: Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N)
    stub_netpar_proposals([ netpar_failed_row(failed) ])
    blob = abandoned.bank_pdf.blob

    get wizard(abandoned, "step5")
    assert_redirected_to wizard(abandoned, "step4")
    abandoned.reload
    assert_equal [ 42, nil, nil, "step3", false ],
                 [ abandoned.esod_category, abandoned.exam_fee_id, abandoned.exam_fee_price, abandoned.status, abandoned.confirm_that_the_data_is_correct ]
    assert_not abandoned.bank_pdf.attached?
    assert_not ActiveStorage::Blob.exists?(blob.id)
    assert_equal [ 501, "Testowy", "81-323" ], [ abandoned.exam_id, abandoned.name, abandoned.c_address_postal_code ] # zakładki 1–3
    follow_redirect!
    assert_select ".flash", text: /Zmienił się rodzaj wniosku na „Wniosek o przeprowadzenie egzaminu poprawkowego”/

    get wizard(abandoned, "step2") # już zgodny – bez zmian i bez komunikatu
    assert_response :success
    assert_select ".flash", count: 0
  end

  test "powrót do szkicu: zmiana rodzaju na wcześniejszej zakładce – komunikat na tej zakładce; NETPAR niedostępny – bez zmian" do
    draft = complete_proposal(@user)
    draft.update_columns(status: "step2")
    failed = submitted_proposal(@user, proposal_status_id: Proposal::PROPOSAL_STATUS_EXAMINATION_RESULT_N)
    stub_request(:get, "#{NETPAR_URL}/proposals").to_timeout
    get wizard(draft, "step2")
    assert_response :success
    assert_equal 41, draft.reload.esod_category

    stub_netpar_proposals([ netpar_failed_row(failed) ])
    get wizard(draft, "step2")
    assert_response :success
    assert_select ".flash", text: /Zmienił się rodzaj wniosku/
    assert_equal [ 42, "step2" ], draft.reload.values_at(:esod_category, :status)
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
