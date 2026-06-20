class ApplicationController < ActionController::Base
  include Pagy::Method

  allow_browser versions: :modern

  helper_method :current_user_email, :current_user_name, :logged_in?

  before_action :require_login

  private

  def current_user_email
    session[:user_email]
  end

  def current_user_name
    session[:user_name]
  end

  def logged_in?
    current_user_email.present?
  end

  def require_login
    redirect_to login_path, alert: "Please sign in to continue." unless logged_in?
  end
end
