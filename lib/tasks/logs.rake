namespace :logs do
  desc "Import Caddy logs from a directory (CADDY_LOGS_DIR=/path/to/logs)"
  task import: :environment do
    dir = CaddyLogImporter.logs_dir

    unless Dir.exist?(dir)
      abort "Directory not found: #{dir}"
    end

    puts "Importing Caddy logs from #{dir}..."
    result = ImportLock.with_exclusive_lock do
      CaddyLogImporter.import_directory(dir)
    end

    if result == false
      puts "Another import is already running, skipping."
    else
      puts "Done! Access: #{result.access_count}, Errors: #{result.error_count}, Skipped: #{result.skipped}"
    end
  end

  desc "Clear all imported logs and tracking data"
  task reset: :environment do
    CaddyLogImporter.reset
    puts "Cleared all logs and import tracking data."
  end
end
