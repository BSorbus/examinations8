require "test_helper"

class ProposalTest < ActiveSupport::TestCase
  setup { @user = create_user }

  test "nowe zgłoszenie: status utworzone i identyfikator" do
    proposal = @user.proposals.build
    assert_equal Proposal::PROPOSAL_STATUS_CREATED, proposal.proposal_status_id
    assert_match(/\A\h{8}-/, proposal.multi_app_identifier)
  end

  test "data zgłoszenia: dla szkicu – rozpoczęcia, po wysłaniu – wysłania (nagłówek, listy, maile); kolejność listy" do
    draft = complete_proposal(@user)
    draft.update_columns(created_at: Time.zone.local(2026, 10, 31, 16, 11, 50))
    assert_match(/\A2026-10-31 16:11:50 \[/, draft.rec_info_short)

    draft.update_columns(submitted_at: Time.zone.local(2026, 10, 31, 20, 15, 13))
    assert_match(/\A2026-10-31 20:15:13 \[/, draft.rec_info_short)
    assert_equal "Zgłoszenie #{draft.rec_info_short}", draft.rec_info

    newer_draft = complete_proposal(@user)
    newer_draft.update_columns(created_at: Time.zone.local(2026, 10, 31, 18, 0, 0))
    assert_equal [ draft, newer_draft ], @user.proposals.newest_first.to_a
  end

  test "walidacja tylko do bieżącego kroku kreatora" do
    proposal = @user.proposals.build(proposal_attributes(pesel: "90010100005", address_combine_id: nil))
    proposal.form_step = "step1"
    assert proposal.valid?, proposal.errors.full_messages.inspect

    proposal.form_step = "step2"
    assert_not proposal.valid?
    assert_equal [ "Pesel jest niepoprawny" ], proposal.errors.full_messages

    proposal.pesel = "90010100009"
    proposal.form_step = "step3"
    assert_not proposal.valid?
    assert_equal [ :address_combine_id ], proposal.errors.attribute_names
  end

  test "data urodzenia niezgodna z PESEL" do
    proposal = @user.proposals.build(proposal_attributes(birth_date: Date.new(1991, 1, 1)))
    proposal.form_step = "step2"
    assert_not proposal.valid?
    assert_equal [ "Data urodzenia niezgodność danych z danymi PESEL" ], proposal.errors.full_messages
  end

  test "minimalny wiek – po „Dalej” na zakładce 2, przy dacie urodzenia, na dzień egzaminu" do
    exam_day = Date.current + 30
    proposal = @user.proposals.build(proposal_attributes(division_min_years_old: 18, exam_date_exam: exam_day, pesel: "",
                                                         birth_date: exam_day - 18.years + 1.day)) # 18 lat kończy dzień po egzaminie
    proposal.form_step = "step1"
    assert proposal.valid?, "na zakładce 1 wiek nie jest sprawdzany"
    proposal.form_step = "step2"
    assert_not proposal.valid?
    assert_equal [ "Data urodzenia - Przystąpienie do egzaminu wymaga ukończenia 18 lat w dniu egzaminu (#{exam_day.strftime('%d.%m.%Y')})" ],
                 proposal.errors.full_messages

    proposal.birth_date = exam_day - 18.years # 18 lat kończy w dniu egzaminu – dziś jeszcze niepełnoletni
    assert proposal.valid?, "wiek liczony na dzień egzaminu, nie na dziś"
  end

  test "dane z konta UKE: imię, nazwisko, e-mail zawsze z konta; pozostałe tylko puste (powrót na zakładkę 1)" do
    proposal = @user.proposals.build(esod_category: Proposal::ESOD_CATEGORY_EGZAMIN)
    proposal.fill_from_profile(@user)
    assert_equal [ "Testowy", "Jan", "jan.testowy@example.com", Date.new(1990, 1, 1), "Gdynia" ],
                 [ proposal.name, proposal.given_names, proposal.email, proposal.birth_date, proposal.birth_place ]

    proposal.birth_place, proposal.name = "Sopot", "Inne"
    proposal.fill_from_profile(@user)
    assert_equal [ "Sopot", "Testowy" ], [ proposal.birth_place, proposal.name ]
  end

  test "ulga w opłacie i zgoda opiekuna – wg wieku w dniu egzaminu (rodzaj dostępny dla niepełnoletnich, np. SRC – 15 lat)" do
    exam_day = Date.current + 30
    fee = { "id" => 10, "price" => "75.0", "price_under18" => "50.0" }
    proposal = @user.proposals.build(proposal_attributes(division_min_years_old: 15, exam_date_exam: exam_day, pesel: ""))
    proposal.form_step = "step2"

    proposal.birth_date = exam_day - 18.years # w dniu egzaminu kończy 18 lat – stawka zwykła, bez zgody opiekuna
    proposal.assign_exam_fee(fee)
    assert proposal.valid?
    assert_equal [ 75, false ], [ proposal.exam_fee_price, proposal.consent_pdf_required? ]

    proposal.birth_date = exam_day - 17.years # w dniu egzaminu 17 lat (wymóg 15 spełniony) – ulga i zgoda opiekuna
    proposal.assign_exam_fee(fee)
    assert proposal.valid?
    assert_equal [ 50, true ], [ proposal.exam_fee_price, proposal.consent_pdf_required? ]
  end

  test "rodzaj z wymogiem 18 lat: osoba niepełnoletnia w dniu egzaminu zatrzymana na zakładce 2 (do ulgi nie dochodzi)" do
    exam_day = Date.current + 30
    proposal = @user.proposals.build(proposal_attributes(division_min_years_old: 18, exam_date_exam: exam_day, pesel: "",
                                                         birth_date: exam_day - 17.years))
    proposal.form_step = "step2"
    assert_not proposal.valid?
    assert_includes proposal.errors[:birth_date].first, "wymaga ukończenia 18 lat w dniu egzaminu"
  end

  test "jedno procedowane zgłoszenie na rodzaj świadectwa – wg NETPAR (statusy 1 i 2, inny multi_app_identifier)" do
    proposal = @user.proposals.build(proposal_attributes)
    proposal.form_step = "step1"
    netpar = ->(status, division_id: 18, uuid: SecureRandom.uuid) { { "multi_app_identifier" => uuid, "division_id" => division_id, "proposal_status_id" => status } }

    proposal.netpar_proposals = [ netpar.(2) ]
    assert_not proposal.valid?
    assert_includes proposal.errors[:division_id], "Jest aktualnie procedowane Twoje zgłoszenie dla tego typu świadectwa"

    proposal.netpar_proposals = [ netpar.(5), netpar.(9), netpar.(1, division_id: 20), netpar.(1, uuid: proposal.multi_app_identifier) ]
    assert proposal.valid?, "zamknięte, inny rodzaj albo to samo zgłoszenie – bez blokady"

    proposal.netpar_proposals = nil
    submitted_proposal(@user) # zgłoszenie w toku tylko w naszej bazie – reguła pyta NETPAR, nie naszej bazy
    assert proposal.valid?
  end

  test "zdjęcie: wymóg z NETPAR (face_image_required rodzaju), niezależnie od służby" do
    proposal = @user.proposals.build(proposal_attributes(category: "M"))
    proposal.assign_division(division_a.merge("face_image_required" => false))
    assert_not proposal.face_image_required?

    proposal.assign_division(division_a.merge("face_image_required" => true))
    assert proposal.face_image_required?

    proposal.reset_division
    assert_not proposal.face_image_required?
  end

  test "załączniki: wymagane wg kategorii i wieku, typ i rozmiar" do
    proposal = @user.proposals.build(proposal_attributes(category: "M", division_face_image_required: true, birth_date: Date.current - 17.years, pesel: ""))
    proposal.form_step = "step4"
    assert_not proposal.valid?
    assert_equal %i[bank_pdf face_image consent_pdf], proposal.errors.attribute_names

    proposal.bank_pdf.attach(io: file_fixture("zdjecie.png").open, filename: "x.png", content_type: "image/png")
    proposal.valid?
    assert_includes proposal.errors[:bank_pdf], "nieprawidłowy typ pliku (wymagany typ PDF)"
  end

  test "po wysłaniu do NETPAR dane kroków nie są ponownie sprawdzane (zmiany przez API)" do
    proposal = submitted_proposal(@user)
    proposal.pesel = "zły"
    assert proposal.valid?
  end

  test "opłata ulgowa do 18 lat" do
    fee = { "id" => 1, "price" => "75.0", "price_under18" => "50.0" }
    adult = @user.proposals.build(birth_date: Date.current - 20.years)
    minor = @user.proposals.build(birth_date: Date.current - 17.years)
    adult.assign_exam_fee(fee)
    minor.assign_exam_fee(fee)
    assert_equal 75, adult.exam_fee_price
    assert_equal 50, minor.exam_fee_price
  end

  test "unieważnienie najpóźniej 14 dni przed egzaminem" do
    assert @user.proposals.build(exam_date_exam: Date.current + 15).can_annul?
    assert_not @user.proposals.build(exam_date_exam: Date.current + 14).can_annul?
    assert_not @user.proposals.build(exam_date_exam: Date.current + 30, proposal_status_id: 3).can_annul?
  end

  test "kontynuacja kreatora od kolejnego kroku" do
    assert_equal "step1", @user.proposals.build.next_step
    assert_equal "step3", @user.proposals.build(status: "step2").next_step
    assert_equal "step5", @user.proposals.build(status: "step5").next_step
    assert_equal "step5", @user.proposals.build(status: Proposal::REQUIRED_PUSH_TO_NETPAR).next_step
  end

  test "czyszczenie niedokończonych po 30 dniach (także bez zapisanego kroku), bez niepewnych wysyłek" do
    old = ->(attrs) { draft_proposal(@user, **attrs).tap { it.update_columns(updated_at: 31.days.ago) } }
    stale = old.(status: "step2")
    never_saved = old.(status: nil)
    uncertain = old.(status: Proposal::REQUIRED_PUSH_TO_NETPAR)
    fresh = draft_proposal(@user, status: "step1")
    sent = submitted_proposal(@user).tap { it.update_columns(updated_at: 31.days.ago) }

    assert_equal 2, Proposal.clean_unsaved
    assert_equal [ fresh, sent, uncertain ].map(&:id).sort, Proposal.where(id: [ stale, never_saved, uncertain, fresh, sent ].map(&:id)).ids.sort
  end

  test "dane dla NETPAR – wszystkie wypełnione kolumny" do
    attributes = complete_proposal(@user).netpar_attributes
    assert_equal "R", attributes["category"]
    assert_equal "75.0", attributes["exam_fee_price"]
    assert_equal attributes["multi_app_identifier"], attributes.fetch("multi_app_identifier")
    assert_not attributes.value?(nil)
  end
end
