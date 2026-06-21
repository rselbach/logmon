class ImportLock < ApplicationRecord
  # How long a held lock is allowed to stay "running" before a later caller
  # force-claims it. Covers a worker/process dying mid-import.
  STALE_AFTER = 15.minutes

  # Atomically claim the single import mutex. Returns true if claimed, false if
  # another import is already running (or the sentinel row is missing). The
  # UPDATE...WHERE guards on state/locked_at, so two racers can't both win and
  # we never hold a long transaction across the import itself.
  def self.acquire
    ImportLock.where(id: 1)
              .where("state = ? OR locked_at < ?", "idle", STALE_AFTER.ago)
              .update_all(state: "running", locked_at: Time.current) > 0
  end

  def self.release
    ImportLock.where(id: 1).update_all(state: "idle", locked_at: nil)
  end

  # Yields inside the mutex. Returns the block's result, or false if the lock
  # was already held. The lock is released only on the acquired path.
  def self.with_exclusive_lock
    return false unless acquire
    begin
      yield
    ensure
      release
    end
  end
end
