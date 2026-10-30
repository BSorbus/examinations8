require "test_helper"

class PrivacyConsentTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_user
    sign_in @user, accepted_privacy: false
  end

  test "bez akceptacji: każda strona prowadzi do informacji o danych osobowych" do
    get "/pl/proposals"
    assert_redirected_to "/pl/privacy_consent"
    get "/pl/proposals/x/wizard/step1"
    assert_redirected_to "/pl/privacy_consent"

    get "/pl/privacy_consent"
    assert_response :success
    assert_select "button", text: "Akceptuję"
    assert_select "form[action='/users/sign_out'] button", text: "Nie akceptuję – wyloguj"
  end

  test "deklaracja dostępności dostępna bez akceptacji" do
    get "/pl/declaration"
    assert_response :success
  end

  test "akceptacja: zapis wersji, czasu i IP, powrót na żądaną stronę" do
    get "/pl/proposals"
    post "/pl/privacy_consent"
    assert_redirected_to "/pl/proposals"

    consent = @user.privacy_consents.sole
    assert_equal [ PrivacyConsent.current_version, "127.0.0.1" ], [ consent.version, consent.ip ]
    assert consent.accepted_at.present?

    get "/pl/proposals"
    assert_response :success
  end

  test "nowa wersja treści wymaga ponownej akceptacji, historia zostaje" do
    post "/pl/privacy_consent"
    settings = Rails.configuration.x.examinations
    previous, settings[:privacy_version] = settings[:privacy_version], "nowa"

    get "/pl/proposals"
    assert_redirected_to "/pl/privacy_consent"
    post "/pl/privacy_consent"
    assert_equal [ previous, "nowa" ], @user.privacy_consents.order(:accepted_at).pluck(:version)
  ensure
    settings[:privacy_version] = previous
  end

  test "API dla NETPAR nie wymaga zgody (inny mechanizm logowania)" do
    get "/api/v1/token"
    assert_response :unauthorized
  end
end
