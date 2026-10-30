require "test_helper"

class ProposalTest < ActiveSupport::TestCase
  setup { @user = create_user }

  test "nowe zgłoszenie: status utworzone i identyfikator" do
    proposal = @user.proposals.build
    assert_equal Proposal::PROPOSAL_STATUS_CREATED, proposal.proposal_status_id
    assert_match(/\A\h{8}-/, proposal.multi_app_identifier)
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

  test "minimalny wiek dla rodzaju świadectwa" do
    proposal = @user.proposals.build(proposal_attributes(division_min_years_old: 18, birth_date: Date.current - 10.years, pesel: ""))
    proposal.form_step = "step1"
    assert_not proposal.valid?
    assert_includes proposal.errors[:division_id], "Przystąpienie do egzaminu wymaga ukończenia 18 lat"
  end

  test "jedno procedowane zgłoszenie na rodzaj świadectwa" do
    submitted_proposal(@user)
    proposal = @user.proposals.build(proposal_attributes)
    proposal.form_step = "step1"
    assert_not proposal.valid?
    assert_includes proposal.errors[:division_id], "Jest aktualnie procedowane Twoje zgłoszenie dla tego typu świadectwa"
  end

  test "załączniki: wymagane wg kategorii i wieku, typ i rozmiar" do
    proposal = @user.proposals.build(proposal_attributes(category: "M", birth_date: Date.current - 17.years, pesel: ""))
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
