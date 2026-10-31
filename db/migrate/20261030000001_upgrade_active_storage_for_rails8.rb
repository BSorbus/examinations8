# ActiveStorage od Rails 6.1/7.0: nazwa usługi przy pliku, tabela wariantów, suma kontrolna opcjonalna.
# Odpowiednik migracji z `bin/rails active_storage:update`, dla bazy z poprzedniej wersji (Rails 5.2).
class UpgradeActiveStorageForRails8 < ActiveRecord::Migration[8.1]
  def up
    # Wszystkie dotychczasowe pliki są na dysku lokalnym (config/storage.yml: local) – PostgreSQL wpisze
    # wartość domyślną w istniejących rekordach. Wartość domyślna zostaje: poprzednia wersja (Rails 5.2) nie zna
    # tej kolumny i zapisuje załączniki bez niej – dzięki temu obie wersje mogą działać na jednej bazie
    # (serwer testowy, ewentualny powrót do poprzedniej wersji). examinations8 zawsze podaje wartość sama.
    if column_exists?(:active_storage_blobs, :service_name)
      change_column_default :active_storage_blobs, :service_name, "local"
    else
      add_column :active_storage_blobs, :service_name, :string, null: false, default: "local"
    end

    create_table :active_storage_variant_records, if_not_exists: true do |t|
      t.belongs_to :blob, null: false, index: false
      t.string :variation_digest, null: false
      t.index [ :blob_id, :variation_digest ], name: "index_active_storage_variant_records_uniqueness", unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    change_column_null :active_storage_blobs, :checksum, true
  end

  def down
    change_column_null :active_storage_blobs, :checksum, false
    drop_table :active_storage_variant_records, if_exists: true
    remove_column :active_storage_blobs, :service_name, if_exists: true
  end
end
