class CreateImportedFiles < ActiveRecord::Migration[8.1]
  def change
    create_table :imported_files do |t|
      t.string :filename, null: false
      t.integer :byte_offset, default: 0, null: false
      t.boolean :completed, default: false, null: false
      t.datetime :last_imported_at

      t.timestamps
    end
    add_index :imported_files, :filename, unique: true
  end
end
