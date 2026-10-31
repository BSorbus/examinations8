require "test_helper"

class ProposalSubmissionTest < ActiveSupport::TestCase
  setup do
    stub_netpar_token
    stub_netpar_proposals
    @proposal = complete_proposal(create_user)
  end

  test "wysłanie: POST do NETPAR, status wysłane, historia, mail po zatwierdzeniu" do
    post = stub_request(:post, "#{NETPAR_URL}/proposals")
      .to_return(json({ proposal: { id: 1, created_at: "2026-10-31T20:15:13.000+01:00" } }, status: 201))

    assert_enqueued_emails 1 do
      assert ProposalSubmission.new(@proposal, confirmed: true).call
    end
    assert_requested post, times: 1
    @proposal.reload
    assert @proposal.submitted?
    assert @proposal.confirm_that_the_data_is_correct
    assert_match %r{\A/rails/active_storage/blobs/}, @proposal.bank_pdf_blob_path
    assert_equal [ "submitted" ], @proposal.events.pluck(:kind)
    assert_equal Time.zone.parse("2026-10-31T20:15:13+01:00"), @proposal.submitted_at # data zgłoszenia wg NETPAR
  end

  test "data zgłoszenia: po niepewnej próbie – wg NETPAR (chwila pierwszego przyjęcia), przed sukcesem pusta, potem bez zmian" do
    stub_request(:post, "#{NETPAR_URL}/proposals").to_timeout # NETPAR zapisał, odpowiedź nie dotarła
    assert_raises(Netpar::Unavailable) { ProposalSubmission.new(@proposal, confirmed: true).call }
    assert_nil @proposal.reload.submitted_at

    stub_request(:patch, "#{NETPAR_URL}/proposals/#{@proposal.multi_app_identifier}")
      .to_return(json({ proposal: { id: 1, created_at: "2026-10-31T20:15:13.000+01:00" } }, status: 200))
    travel 10.minutes do
      assert ProposalSubmission.new(@proposal, confirmed: true).call
      assert ProposalSubmission.new(@proposal, confirmed: true).call # już wysłane – bez zmian
    end
    assert_equal Time.zone.parse("2026-10-31T20:15:13+01:00"), @proposal.reload.submitted_at
  end

  test "data zgłoszenia: odpowiedź NETPAR bez created_at – nasz zegar" do
    stub_request(:post, "#{NETPAR_URL}/proposals").to_return(json({ id: 1 }, status: 201))
    assert ProposalSubmission.new(@proposal, confirmed: true).call
    assert_in_delta Time.current, @proposal.reload.submitted_at, 5.seconds
  end

  test "bez potwierdzenia danych: nic nie idzie do NETPAR" do
    assert_not ProposalSubmission.new(@proposal, confirmed: false).call
    assert_includes @proposal.errors[:confirm_that_the_data_is_correct], "Musisz potwierdzić poprawność danych"
    assert_not_requested :post, "#{NETPAR_URL}/proposals"
  end

  test "błąd NETPAR: zgłoszenie zostaje do ponownego wysłania, bez maila" do
    stub_request(:post, "#{NETPAR_URL}/proposals").to_timeout
    assert_no_enqueued_emails do
      assert_raises(Netpar::Unavailable) { ProposalSubmission.new(@proposal, confirmed: true).call }
    end
    @proposal.reload
    assert_equal Proposal::REQUIRED_PUSH_TO_NETPAR, @proposal.status
    assert_not @proposal.submitted?
  end

  test "ponowienie po niepewnej próbie: najpierw PATCH (bez duplikatu w NETPAR)" do
    @proposal.update_columns(status: Proposal::REQUIRED_PUSH_TO_NETPAR)
    patch = stub_request(:patch, "#{NETPAR_URL}/proposals/#{@proposal.multi_app_identifier}").to_return(json({}, status: 200))

    assert ProposalSubmission.new(@proposal, confirmed: true).call
    assert_requested patch.with { !URI.decode_www_form(it.body).to_h["proposal"].include?("proposal_status_id") }, times: 1
    assert_not_requested :post, "#{NETPAR_URL}/proposals"
    assert @proposal.reload.submitted?
  end

  test "ponowienie, gdy poprzednia próba nie dotarła do NETPAR: PATCH 404 → POST" do
    @proposal.update_columns(status: Proposal::REQUIRED_PUSH_TO_NETPAR)
    stub_request(:patch, "#{NETPAR_URL}/proposals/#{@proposal.multi_app_identifier}").to_return(json({}, status: 404))
    post = stub_request(:post, "#{NETPAR_URL}/proposals").to_return(json({}, status: 201))

    assert ProposalSubmission.new(@proposal, confirmed: true).call
    assert_requested post, times: 1
  end

  test "już wysłane: bez wywołania NETPAR" do
    @proposal.update_columns(status: Proposal::SAVED_IN_NETPAR, confirm_that_the_data_is_correct: true)
    assert ProposalSubmission.new(@proposal, confirmed: true).call
    assert_not_requested :any, %r{/proposals}
  end
end
