class ApiKeyToken < ApplicationRecord
  belongs_to :api_key

  def self.digest(token) = OpenSSL::Digest::SHA256.hexdigest(token.to_s)
end
