# Klucze API bez jawnych sekretów w bazie: hasło jako skrót bcrypt, tokeny w osobnej tabeli jako skrót SHA256,
# ważne ograniczony czas (kilka naraz – każdy proces NETPAR pobiera własny token).
# Jawne kolumny api_keys.password i access_token zostają do czasu udanego przełączenia na examinations8
# (możliwość powrotu do poprzedniej wersji) – model je ignoruje; usunie je późniejsza migracja.
class SecureApiKeys < ActiveRecord::Migration[8.1]
  def up
    add_column :api_keys, :password_digest, :string

    create_table :api_key_tokens do |t|
      t.references :api_key, null: false, foreign_key: true
      t.string :token_digest, null: false, index: { unique: true }
      t.datetime :expires_at, null: false, index: true
      t.timestamps
    end

    select_rows("SELECT id, password FROM api_keys WHERE password IS NOT NULL").each do |id, password|
      execute ActiveRecord::Base.sanitize_sql([ "UPDATE api_keys SET password_digest = ? WHERE id = ?", BCrypt::Password.create(password), id ])
    end
  end

  def down
    drop_table :api_key_tokens
    remove_column :api_keys, :password_digest
  end
end
