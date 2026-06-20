namespace :logs do
  desc "Import Caddy logs from a directory (CADDY_LOGS_DIR=/path/to/logs)"
  task import: :environment do
    dir = ENV["CADDY_LOGS_DIR"] || File.expand_path("../caddy", Rails.root)

    unless Dir.exist?(dir)
      abort "Directory not found: #{dir}"
    end

    puts "Importing Caddy logs from #{dir}..."
    result = CaddyLogImporter.import_directory(dir)
    puts "Done! Access: #{result.access_count}, Errors: #{result.error_count}, Skipped: #{result.skipped}"
  end

  desc "Clear all imported logs and tracking data"
  task reset: :environment do
    CaddyLogImporter.reset
    puts "Cleared all logs and import tracking data."
  end
end
