class CreateAccessLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :access_logs do |t|
      t.datetime :timestamp
      t.string :remote_ip
      t.string :client_ip
      t.string :method
      t.string :host
      t.text :uri
      t.integer :status
      t.integer :size
      t.integer :bytes_read
      t.float :duration
      t.string :proto
      t.text :user_agent
      t.text :referer
      t.integer :tls_version
      t.string :tls_proto
      t.string :server_name
      t.string :request_id

      t.timestamps
    end
    add_index :access_logs, :timestamp
    add_index :access_logs, :remote_ip
    add_index :access_logs, :host
    add_index :access_logs, :status
    add_index :access_logs, :method
  end
end
