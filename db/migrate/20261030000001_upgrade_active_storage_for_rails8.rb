# ActiveStorage od Rails 6.1/7.0: nazwa usługi przy pliku, tabela wariantów, suma kontrolna opcjonalna.
# Odpowiednik migracji z `bin/rails active_storage:update`, dla bazy z poprzedniej wersji (Rails 5.2).
class UpgradeActiveStorageForRails8 < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:active_storage_blobs, :service_name)
      add_column :active_storage_blobs, :service_name, :string
      # Wszystkie dotychczasowe pliki są na dysku lokalnym (config/storage.yml: local).
      execute "UPDATE active_storage_blobs SET service_name = 'local'"
      change_column_null :active_storage_blobs, :service_name, false
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
