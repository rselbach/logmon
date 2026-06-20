class CreateErrorLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :error_logs do |t|
      t.datetime :timestamp
      t.string :level
      t.string :source
      t.text :message
      t.string :remote_ip
      t.string :method
      t.string :host
      t.text :uri
      t.integer :status
      t.float :duration
      t.string :err_id
      t.string :err_trace

      t.timestamps
    end
    add_index :error_logs, :timestamp
    add_index :error_logs, :remote_ip
    add_index :error_logs, :host
    add_index :error_logs, :status
  end
end
