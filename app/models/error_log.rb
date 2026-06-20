class ErrorLog < ApplicationRecord
  scope :recent, -> { order(timestamp: :desc) }
  scope :by_status, ->(status) { where(status: status) }
  scope :by_host, ->(host) { where(host: host) }
  scope :by_ip, ->(ip) { where(remote_ip: ip) }
  scope :search, ->(q) {
    where("message LIKE :q OR host LIKE :q OR remote_ip LIKE :q OR uri LIKE :q", q: "%#{q}%")
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

  def self.top_hosts(limit = 10)
    group(:host).count.sort_by { |_, count| -count }.first(limit)
  end

  def self.top_ips(limit = 10)
    group(:remote_ip).count.sort_by { |_, count| -count }.first(limit)
  end
end
