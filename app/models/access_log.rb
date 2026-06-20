class AccessLog < ApplicationRecord
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_method, ->(method) { where(method: method) }
  scope :by_host, ->(host) { where(host: host) }
  scope :by_ip, ->(ip) { where(remote_ip: ip) }
  scope :search, ->(q) {
    where("uri LIKE :q OR host LIKE :q OR remote_ip LIKE :q OR user_agent LIKE :q", q: "%#{q}%")
  }
  scope :in_range, ->(from, to) { where(timestamp: from..to) }

  STATUS_CLASSES = {
    200..299 => "text-emerald-600 bg-emerald-50",
    300..399 => "text-blue-600 bg-blue-50",
    400..499 => "text-amber-600 bg-amber-50",
    500..599 => "text-red-600 bg-red-50",
  }.freeze

  def status_badge_class
    STATUS_CLASSES.find { |range, _| range.include?(status.to_i) }&.last || "text-gray-600 bg-gray-50"
  end

  def self.status_counts
    group(:status).count.sort_by { |status, _| status.to_i }
  end

  def self.top_hosts(limit = 10)
    group(:host).count.sort_by { |_, count| -count }.first(limit)
  end

  def self.top_ips(limit = 10)
    group(:remote_ip).count.sort_by { |_, count| -count }.first(limit)
  end

  def self.top_paths(limit = 10)
    group(:uri).count.sort_by { |_, count| -count }.first(limit)
  end

  def self.top_user_agents(limit = 10)
    where.not(user_agent: nil).group(:user_agent).count.sort_by { |_, count| -count }.first(limit)
  end

  def self.browser_counts
    sql = <<~SQL
      CASE
        WHEN user_agent LIKE '%Edg%' THEN 'Edge'
        WHEN user_agent LIKE '%OPR%' THEN 'Opera'
        WHEN user_agent LIKE '%Firefox%' THEN 'Firefox'
        WHEN user_agent LIKE '%Chrome%' THEN 'Chrome'
        WHEN user_agent LIKE '%Safari%' THEN 'Safari'
        WHEN user_agent IS NULL OR user_agent = '' THEN 'Unknown'
        ELSE 'Other'
      END
    SQL
    where.not(user_agent: [nil, ""])
      .group(sql)
      .count
      .sort_by { |_, count| -count }
  end

  def self.os_counts
    sql = <<~SQL
      CASE
        WHEN user_agent LIKE '%Android%' THEN 'Android'
        WHEN user_agent LIKE '%iPhone%' OR user_agent LIKE '%iPad%' THEN 'iOS'
        WHEN user_agent LIKE '%Windows NT%' THEN 'Windows'
        WHEN user_agent LIKE '%Macintosh%' OR user_agent LIKE '%Mac OS X%' THEN 'macOS'
        WHEN user_agent LIKE '%CrOS%' THEN 'ChromeOS'
        WHEN user_agent LIKE '%Linux%' THEN 'Linux'
        WHEN user_agent IS NULL OR user_agent = '' THEN 'Unknown'
        ELSE 'Other'
      END
    SQL
    where.not(user_agent: [nil, ""])
      .group(sql)
      .count
      .sort_by { |_, count| -count }
  end

  def self.method_counts
    group(:method).count.sort_by { |_, count| -count }
  end

  def self.requests_per_hour(hours = 24)
    now = Time.current
    from_time = (now - (hours - 1).hours).beginning_of_hour

    counts = where("timestamp >= ?", from_time)
             .group("strftime('%Y-%m-%d %H:00', timestamp)")
             .count

    results = {}
    hours.times do |i|
      hour_start = (now - (hours - 1 - i).hours).beginning_of_hour
      key = hour_start.strftime("%H:%M")
      bucket = hour_start.strftime("%Y-%m-%d %H:00")
      results[key] = counts[bucket] || 0
    end
    results
  end
end
