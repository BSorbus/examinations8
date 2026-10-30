# Linki do załączników zapisane przez poprzednią wersję (Rails 5.2) – NETPAR pokazuje je urzędnikom
# (proposals.*_blob_path). Rails 5.2 wyprowadzał klucz podpisu przez PBKDF2-SHA1 i serializował Marshalem,
# Rails 8 używa SHA256: nowe linki podpisujemy nowym kluczem, a stare przyjmujemy dzięki rotacji.
# Wymaga tego samego secret_key_base co w poprzedniej wersji (credentials).
Rails.application.message_verifiers.rotate do |salt|
  next unless salt == "ActiveStorage"

  {
    secret_generator: lambda do |name|
      ActiveSupport::KeyGenerator
        .new(Rails.application.secret_key_base, iterations: 1000, hash_digest_class: OpenSSL::Digest::SHA1)
        .generate_key(name)
    end,
    serializer: Marshal,
    url_safe: false
  }
end
