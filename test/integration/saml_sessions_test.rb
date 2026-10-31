require "test_helper"

class SamlSessionsTest < ActionDispatch::IntegrationTest
  test "wylogowanie: przekierowanie do wylogowania w WSO2 i koniec sesji" do
    sign_in create_user
    delete "/users/sign_out"
    assert_response :see_other
    assert_match %r{\Ahttps://idp\.test/samlsso\?slo=true&spEntityID=issuer\.egzaminy&returnTo=.*&SAMLRequest=}, response.location
    get "/pl/proposals"
    assert_redirected_to "/users/saml/sign_in"
  end
end
