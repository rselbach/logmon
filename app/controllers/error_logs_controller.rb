class ErrorLogsController < ApplicationController
  def index
    scope = ErrorLog.recent

    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.by_status(params[:status]) if params[:status].present?
    scope = scope.by_host(params[:host]) if params[:host].present?
    scope = scope.by_ip(params[:ip]) if params[:ip].present?

    @pagy, @logs = pagy(scope, limit: 50)

    @hosts = ErrorLog.distinct.pluck(:host).compact.sort
    @statuses = ErrorLog.distinct.pluck(:status).compact.sort
  end

  def show
    @log = ErrorLog.find(params[:id])
  end
end
