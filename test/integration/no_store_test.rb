require "test_helper"

# Cache-Control: no-store dla stron z danymi osobowymi po zalogowaniu (raport bezpieczeństwa 2026-11-20).
class NoStoreTest < ActionDispatch::IntegrationTest
  setup do
    stub_netpar_token
    @user = create_user
    sign_in @user
  end

  def assert_no_store(path)
    get path
    assert_includes [ 200, 302 ], response.status, path
    assert_equal "no-store", response.headers["Cache-Control"], path
  end

  test "lista, szczegóły, kreator, informacja RODO, podpowiedzi adresów – no-store" do
    draft = draft_proposal(@user, status: "step1")
    submitted = submitted_proposal(@user, proposal_status_id: 2)
    stub_request(:get, %r{#{NETPAR_URL}/proposals/}).to_return(json({ grades: [] }))

    assert_no_store "/pl/proposals"
    assert_no_store "/pl/proposals/#{submitted.multi_app_identifier}"
    assert_no_store "/pl/proposals/#{draft.multi_app_identifier}/wizard/step1"
    assert_no_store "/pl/privacy_consent"
    assert_no_store "/pl/lookups/addresses?q=gd"
  end

  test "strona egzaminu online: no-store, formularz i ramka TestPortal bez zmian" do
    proposal = submitted_proposal(@user, proposal_status_id: 2, exam_online: true, test_unlocked: true)
    stub_request(:get, "#{NETPAR_URL}/proposals/#{proposal.multi_app_identifier}/grades")
      .to_return(json({ grades: [ { "testportal_access_code_id" => "KOD1", "subject_name" => "Przepisy" } ] }))

    assert_no_store "/pl/proposals/#{proposal.multi_app_identifier}/testportal"
    assert_select "form[action='https://egzaminyuke.testportal.pl/exam/start.html'][method=post][target=test-frame]"
    assert_select "iframe[name=test-frame]"
  end

  test "strony publiczne i załączniki (Active Storage) – bez zmian" do
    get "/pl"
    assert_not_equal "no-store", response.headers["Cache-Control"]

    proposal = complete_proposal(@user)
    get Rails.application.routes.url_helpers.rails_blob_path(proposal.bank_pdf, only_path: true)
    assert_not_equal "no-store", response.headers["Cache-Control"]
  end
end
