# Historia zgłoszenia: wysłanie do NETPAR, zmiany z NETPAR (status, komentarz, sesja), maile, unieważnienie.
class CreateProposalEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :proposal_events do |t|
      t.references :proposal, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false
      t.jsonb :data, null: false, default: {}
      t.datetime :created_at, null: false
    end
  end
end
