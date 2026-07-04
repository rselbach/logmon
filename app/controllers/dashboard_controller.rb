class DashboardController < ApplicationController
  RANGE_PRESETS = %w[24h 7d 30d all].freeze
  DEFAULT_RANGE = "24h"
  DURATION_RE = /\A(\d+)\s*([hdw])?\z/i

  def index
    @current_range = params[:range].presence || DEFAULT_RANGE
    seconds = parse_range_seconds(@current_range)

    @to = Time.current
    @from = seconds ? @to - seconds : nil

    access = @from ? AccessLog.where("timestamp >= ?", @from) : AccessLog
    errors = @from ? ErrorLog.where("timestamp >= ?", @from) : ErrorLog

    @total_requests = access.count
    @total_errors = errors.count
    @error_rate = @total_requests.positive? ? (@total_errors.to_f / @total_requests * 100).round(2) : 0
    @unique_ips = access.distinct.count(:remote_ip)

    @status_counts = access.status_counts
    @method_counts = access.method_counts
    @top_hosts = access.top_hosts(10)
    @top_ips = access.top_ips(10)
    @top_paths = access.top_paths(10)
    @top_user_agents = access.top_user_agents(10)
    @browser_counts = access.browser_counts
    @os_counts = access.os_counts
    @requests_over_time = AccessLog.requests_over_time(@from, @to)
    @recent_errors = errors.recent.limit(10)

    @range_label = range_label_for(@current_range, seconds)
    @custom_range_value = RANGE_PRESETS.include?(@current_range) ? "" : @current_range
  end

  def refresh
    CaddyLogImporterJob.perform_later

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "refresh_button",
          partial: "dashboard/refresh_button",
          locals: { importing: true }
        )
      end
      format.html { redirect_to root_path, notice: "Import queued." }
    end
  end

  private

  def parse_range_seconds(str)
    return nil if str.blank? || str.casecmp("all") == 0
    if (m = str.match(DURATION_RE))
      num = m[1].to_i
      case (m[2] || "h").downcase
      when "h" then num.hours
      when "d" then num.days
      when "w" then num.weeks
      end
    else
      24.hours
    end
  end

  def range_label_for(range, seconds)
    return "All Time" if seconds.nil?
    m = range.match(DURATION_RE)
    return "Last 24 hours" unless m
    num = m[1].to_i
    unit = (m[2] || "h").downcase
    name = { "h" => "hour", "d" => "day", "w" => "week" }.fetch(unit)
    "Last #{num} #{num == 1 ? name : "#{name}s"}"
  end
end
