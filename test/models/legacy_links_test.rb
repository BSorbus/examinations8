require "test_helper"

class LegacyLinksTest < ActiveSupport::TestCase
  test "linki do załączników podpisane przez poprzednią wersję (Rails 5.2) nadal działają" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("przelew.pdf").open, filename: "przelew.pdf")
    # Podpis dokładnie jak w Rails 5.2 (MessageVerifier#generate z purpose): klucz PBKDF2-SHA1,
    # Base64(JSON {"_rails": {"message": Base64(Marshal(id)), "exp": nil, "pur": "blob_id"}}) + "--" + HMAC-SHA1.
    key = ActiveSupport::KeyGenerator.new(Rails.application.secret_key_base, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1)
                                     .generate_key("ActiveStorage")
    metadata = { "_rails" => { "message" => Base64.strict_encode64(Marshal.dump(blob.id)), "exp" => nil, "pur" => "blob_id" } }
    data = Base64.strict_encode64(JSON.dump(metadata))
    signed = "#{data}--#{OpenSSL::HMAC.hexdigest("SHA1", key, data)}"

    assert_equal blob, ActiveStorage::Blob.find_signed(signed)
    assert_equal blob, ActiveStorage::Blob.find_signed(blob.signed_id) # nowe linki
  end
end
