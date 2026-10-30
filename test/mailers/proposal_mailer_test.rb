require "test_helper"

class ProposalMailerTest < ActionMailer::TestCase
  setup { @proposal = submitted_proposal(create_user) }

  # Maile z obrazkami w treści są wieloczęściowe – treść w części HTML.
  def html(mail) = mail.html_part.decoded

  test "mail dla statusu: adresat, temat, link do zgłoszenia, wpis w historii" do
    mail = ProposalMailer.for_status(@proposal)
    mail.deliver_now
    assert_equal [ "jan.testowy@example.com" ], mail.to
    assert_match(/\AUKE Egzaminy - Zgłoszenie /, mail.subject)
    assert_includes html(mail), "http://egzaminy.test/pl/proposals/#{@proposal.multi_app_identifier}"
    assert_equal({ "template" => "created", "to" => "jan.testowy@example.com" }, @proposal.events.last.data)
  end

  test "zaakceptowane online – osobny szablon" do
    @proposal.update_columns(proposal_status_id: 2, exam_online: true)
    assert_match "LOGIN oraz HASŁO", html(ProposalMailer.for_status(@proposal))
  end

  test "komentarz z NETPAR bez znaczników HTML (simple_format usuwa niebezpieczne)" do
    @proposal.update_columns(proposal_status_id: 3, not_approved_comment: "<script>alert(1)</script>\nlinia 2")
    body = html(ProposalMailer.for_status(@proposal))
    assert_not_includes body, "<script"
    assert_includes body, "alert(1)"
  end

  test "przypomnienia 3 dni przed egzaminem" do
    @proposal.update_columns(proposal_status_id: 2, exam_date_exam: Date.current + 3)
    assert_emails 1 do
      assert_equal 1, Proposal.send_reminders
    end
  end
end
