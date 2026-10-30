# Klucz dostępu systemu zewnętrznego (NETPAR) do API aplikacji. Jak w poprzedniej wersji NETPAR pobiera token:
# GET /api/v1/token z Basic Auth (name/password), a potem wysyła go w nagłówku "Authorization: Token token=…".
# W bazie nie ma jawnych sekretów: hasło – bcrypt, tokeny – SHA256 z ograniczonym czasem ważności.
class ApiKey < ApplicationRecord
  TOKEN_TTL = 1.hour

  # Jawne kolumny z poprzedniej wersji – do usunięcia po przełączeniu (patrz migracja SecureApiKeys).
  self.ignored_columns += %w[password access_token]

  has_secure_password
  has_many :tokens, class_name: "ApiKeyToken", dependent: :delete_all

  validates :name, presence: true, length: { in: 1..30 }, uniqueness: { case_sensitive: false }

  def self.authenticate(name, password)
    find_by(name: name.to_s)&.authenticate(password.to_s) || nil
  end

  # Nowy token (zwracany tylko raz – w bazie zostaje skrót). Przy okazji usuwa wygasłe.
  def issue_token
    tokens.where(expires_at: ...Time.current).delete_all
    token = SecureRandom.base58(40)
    tokens.create!(token_digest: ApiKeyToken.digest(token), expires_at: TOKEN_TTL.from_now)
    token
  end

  def self.find_by_token(token)
    return if token.blank?

    ApiKeyToken.where(expires_at: Time.current..).find_by(token_digest: ApiKeyToken.digest(token))&.api_key
  end
end
