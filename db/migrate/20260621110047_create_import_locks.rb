class CreateImportLocks < ActiveRecord::Migration[8.1]
  def change
    create_table :import_locks do |t|
      t.string :state, null: false, default: "idle"
      t.datetime :locked_at
      t.timestamps
    end

    # Seed the single sentinel row used by ImportLock. Raw SQL (not the model)
    # so the migration stays decoupled from the model's current shape.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO import_locks (id, state, created_at, updated_at)
          VALUES (1, 'idle', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
        SQL
      end
    end
  end
end
