class CaddyLogImporterJob < ApplicationJob
  # SolidQueue-level guard: a mashing button won't stack duplicate jobs. This
  # only governs jobs enqueued through SolidQueue, though — the systemd timer
  # runs `rails logs:import` directly, so ImportLock (the DB mutex) is the real
  # cross-path guard that covers BOTH the job and the rake task.
  limits_concurrency to: 1, key: -> { "caddy-import" }, on_conflict: :discard, duration: 15.minutes

  def perform
    result = ImportLock.with_exclusive_lock do
      CaddyLogImporter.import_directory(CaddyLogImporter.logs_dir)
    end

    if result == false
      logger.info("CaddyLogImporterJob: another import is running, skipped")
    end
  rescue => e
    # No silent failures: log loudly. Don't auto-retry — a retry would just
    # re-contend for the mutex. The broadcast in +ensure+ still reloads the page
    # so the button resets and the user sees the current state.
    logger.error("CaddyLogImporterJob failed: #{e.class}: #{e.message}")
  ensure
    # Tell any open dashboard to reload with fresh data, whether we imported,
    # no-op'd (lock held), or failed. request_id is nil here (no HTTP context),
    # so Turbo won't treat this as a self-triggered refresh and skip it.
    Turbo::StreamsChannel.broadcast_refresh_to("dashboard")
  end
end
