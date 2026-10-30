# Akceptacja informacji o przetwarzaniu danych osobowych (RODO): kto, którą wersję treści, kiedy i z jakiego adresu IP.
# Historia akceptacji zostaje także po zmianie treści (nowa wersja = ponowna akceptacja) – zasada rozliczalności.
class CreatePrivacyConsents < ActiveRecord::Migration[8.1]
  def change
    create_table :privacy_consents do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :version, null: false
      t.datetime :accepted_at, null: false
      t.string :ip
      t.index [ :user_id, :version ], unique: true
    end
  end
end
