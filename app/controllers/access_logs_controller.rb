class AccessLogsController < ApplicationController
  def index
    scope = AccessLog.recent

    scope = scope.search(params[:q]) if params[:q].present?
    scope = scope.by_status(params[:status]) if params[:status].present?
    scope = scope.by_method(params[:method]) if params[:method].present?
    scope = scope.by_host(params[:host]) if params[:host].present?
    scope = scope.by_ip(params[:ip]) if params[:ip].present?

    @pagy, @logs = pagy(scope, limit: 50)

    @hosts = AccessLog.distinct.pluck(:host).compact.sort
    @methods = AccessLog.distinct.pluck(:method).compact.sort
    @statuses = AccessLog.distinct.pluck(:status).compact.sort
  end

  def show
    @log = AccessLog.find(params[:id])
  end
end
