ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Dane i odpowiedzi usług zewnętrznych (NETPAR, TERYT) – fikcyjne, w formacie ich API.
module ServiceStubs
  NETPAR_URL = "https://netpar.test/api/v1"
  TERYT_URL = "https://teryt.test"

  def division_a = { "id" => 18, "category" => "R", "name" => "świadectwo klasy A", "short_name" => "A", "number_prefix" => "A-",
                     "min_years_old" => 0, "face_image_required" => false, "fullname" => "świadectwo klasy A, [A]",
                     "proposal_via_internet" => true }

  def exam_r(overrides = {})
    { "id" => 501, "number" => "R/1/2026", "date_exam" => (Date.current + 30).to_s, "place_exam" => "Gdynia", "info" => "sala 1",
      "province_name" => "POMORSKIE", "online" => false, "category" => "R",
      "fullname" => "R/1/2026, #{Date.current + 30}, Gdynia [POMORSKIE], sala 1" }.merge(overrides)
  end

  def teryt_address = { "combineId" => "2262011093410013296_81-323", "provinceCode" => "22", "provinceName" => "POMORSKIE",
                        "districtCode" => "62", "districtName" => "Gdynia", "communeCode" => "01", "communeName" => "Gdynia",
                        "cityCode" => "0934100", "cityName" => "Gdynia", "parentCityCode" => "0934100", "parentCityName" => "Gdynia",
                        "streetCode" => "13296", "streetName" => "Morska", "streetAttribute" => "ul.", "postCode" => "81-323" }

  def json(body, status: 200) = { status:, body: body.to_json, headers: { "Content-Type" => "application/json" } }

  def stub_netpar_token = stub_request(:get, "#{NETPAR_URL}/token").to_return(json({ token: "tok-1" }))

  # Zgłoszenia użytkownika w NETPAR (GET /proposals?creator_id=) – domyślnie brak.
  def stub_netpar_proposals(rows = [])
    stub_request(:get, "#{NETPAR_URL}/proposals").to_return(json({ proposals: rows, meta: { total_count: rows.size } }))
  end

  def stub_netpar_catalog
    stub_netpar_token
    stub_netpar_proposals
    stub_request(:get, "#{NETPAR_URL}/divisions").to_return(json({ divisions: [ division_a ], meta: { total_count: 1 } }))
    stub_request(:get, "#{NETPAR_URL}/divisions/18").to_return(json(division_a))
    stub_request(:get, "#{NETPAR_URL}/exams").to_return(json({ exams: [ exam_r ], meta: { total_count: 1 } }))
    stub_request(:get, "#{NETPAR_URL}/exams/501").to_return(json(exam_r))
    stub_request(:get, "#{NETPAR_URL}/exam_fees/find").to_return(json({ "id" => 10, "price" => "75.0", "price_under18" => "50.0" }))
    stub_request(:get, "#{TERYT_URL}/Address/#{teryt_address['combineId']}").to_return(json(teryt_address))
  end
end

# Zgłoszenia i użytkownicy w różnych stanach (baza testowa jest pusta).
module ProposalFactory
  def create_user(email: "jan.testowy@example.com", **attributes)
    User.create!(email:, first_name: "Jan", last_name: "Testowy", birth_date: Date.new(1990, 1, 1), birth_city: "Gdynia",
                 family_name: "Testowy", pesel: "90010100009", **attributes)
  end

  def proposal_attributes(overrides = {})
    { esod_category: Proposal::ESOD_CATEGORY_EGZAMIN, email: "jan.testowy@example.com", name: "Testowy", given_names: "Jan",
      pesel: "90010100009", citizenship_code: "PL", birth_date: Date.new(1990, 1, 1), birth_place: "Gdynia", family_name: "Testowy",
      lives_in_poland: true, address_combine_id: teryt_address["combineId"], city_name: "Gdynia", c_address_house: "1",
      c_address_postal_code: "81-323", category: "R", division_id: 18, division_short_name: "A", division_fullname: "świadectwo klasy A, [A]",
      division_min_years_old: 0, exam_id: 501, exam_fullname: exam_r["fullname"], exam_date_exam: Date.current + 30,
      exam_fee_id: 10, exam_fee_price: 75 }.merge(overrides)
  end

  # Zgłoszenie z wypełnionymi krokami 1–4 (załącznik przelewu), gotowe do wysłania.
  def complete_proposal(user, **overrides)
    proposal = user.proposals.build(proposal_attributes(overrides).merge(status: "step4"))
    proposal.bank_pdf.attach(io: file_fixture("przelew.pdf").open, filename: "przelew.pdf", content_type: "application/pdf")
    proposal.save!(validate: false)
    proposal
  end

  # Niedokończone zgłoszenie (zapis bez walidacji – jak w ProposalsController#create).
  def draft_proposal(user, **attributes)
    user.proposals.build(esod_category: Proposal::ESOD_CATEGORY_EGZAMIN, **attributes).tap { it.save!(validate: false) }
  end

  def submitted_proposal(user, **overrides)
    complete_proposal(user, **overrides).tap do |proposal|
      proposal.update_columns(status: Proposal::SAVED_IN_NETPAR, confirm_that_the_data_is_correct: true)
    end
  end
end

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    include ServiceStubs
    include ProposalFactory
    include ActiveJob::TestHelper
    include ActionMailer::TestHelper

    setup do
      Rails.cache.clear
      WebMock.disable_net_connect!
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Zalogowany użytkownik z zaakceptowaną informacją o danych osobowych (bramkę RODO sprawdza osobny test).
  def sign_in(user, accepted_privacy: true, **)
    user.privacy_consents.find_or_create_by!(version: PrivacyConsent.current_version) { it.accepted_at = Time.current } if accepted_privacy
    super(user, **)
  end
end
