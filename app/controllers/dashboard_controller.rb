class DashboardController < ApplicationController
  def index
    @total_requests = AccessLog.count
    @total_errors = ErrorLog.count
    @error_rate = @total_requests.positive? ? (@total_errors.to_f / @total_requests * 100).round(2) : 0

    @status_counts = AccessLog.status_counts
    @method_counts = AccessLog.method_counts
    @top_hosts = AccessLog.top_hosts(10)
    @top_ips = AccessLog.top_ips(10)
    @top_paths = AccessLog.top_paths(10)
    @top_user_agents = AccessLog.top_user_agents(10)
    @browser_counts = AccessLog.browser_counts
    @os_counts = AccessLog.os_counts
    @requests_per_hour = AccessLog.requests_per_hour(24)
    @recent_errors = ErrorLog.recent.limit(10)
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
end
