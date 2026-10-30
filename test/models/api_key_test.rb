require "test_helper"

class ApiKeyTest < ActiveSupport::TestCase
  setup { @key = ApiKey.create!(name: "netpar2015", password: "tajne") }

  test "hasło jako skrót, logowanie" do
    assert_not_equal "tajne", @key.password_digest
    assert_equal @key, ApiKey.authenticate("netpar2015", "tajne")
    assert_nil ApiKey.authenticate("netpar2015", "złe")
    assert_nil ApiKey.authenticate("inny", "tajne")
  end

  test "token: w bazie skrót, ważny godzinę, kilka naraz" do
    first, second = @key.issue_token, @key.issue_token
    assert_equal @key, ApiKey.find_by_token(first)
    assert_equal @key, ApiKey.find_by_token(second)
    assert_not ApiKeyToken.exists?(token_digest: first)

    travel ApiKey::TOKEN_TTL + 1.minute do
      assert_nil ApiKey.find_by_token(first)
    end
  end
end
