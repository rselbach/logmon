require "net/http"

class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new callback apple_callback failure]
  skip_before_action :verify_authenticity_token, only: %i[apple_callback]

  GITHUB_AUTHORIZE_URL = "https://github.com/login/oauth/authorize"
  GITHUB_TOKEN_URL = URI("https://github.com/login/oauth/access_token")
  GITHUB_USER_URL = URI("https://api.github.com/user")
  GITHUB_EMAILS_URL = URI("https://api.github.com/user/emails")

  APPLE_AUTHORIZE_URL = "https://appleid.apple.com/auth/authorize"
  APPLE_TOKEN_URL = URI("https://appleid.apple.com/auth/token")

  def new
    @github_configured = github_client_id.present?
    @apple_configured = apple_configured?

    unless @github_configured || @apple_configured
      @error = "No login provider is configured. Set GitHub or Apple OAuth environment variables."
      return
    end

    if @github_configured
      @state = SecureRandom.hex(16)
      session[:oauth_state] = @state
      @authorize_url = "#{GITHUB_AUTHORIZE_URL}?#{URI.encode_www_form(
        client_id: github_client_id,
        redirect_uri: ENV.fetch("GITHUB_CALLBACK_URL", ""),
        scope: "user:email",
        state: @state
      )}"
    end

    if @apple_configured
      @apple_state = SecureRandom.hex(16)
      cookies[:apple_oauth_state] = { value: @apple_state, same_site: :none, secure: true, httponly: true, expires: 10.minutes }
      @apple_authorize_url = "#{APPLE_AUTHORIZE_URL}?#{URI.encode_www_form(
        client_id: apple_client_id,
        redirect_uri: ENV.fetch("APPLE_CALLBACK_URL", ""),
        response_type: "code",
        response_mode: "form_post",
        scope: apple_scopes,
        state: @apple_state
      )}"
    end
  end

  def callback
    if params[:state].blank? || params[:state] != session[:oauth_state]
      redirect_to login_path, alert: "Invalid OAuth state. Please try again."
      return
    end
    session.delete(:oauth_state)

    token = exchange_code_for_token(params[:code])
    unless token
      redirect_to login_path, alert: "GitHub did not return an access token."
      return
    end

    profile = fetch_github_user(token)
    unless profile
      redirect_to login_path, alert: "Could not fetch your GitHub profile."
      return
    end

    email = profile[:email]&.downcase
    unless email && email_allowed?(email)
      reset_session
      redirect_to login_path, alert: "Access denied: #{email || 'no verified email'} is not on the allowlist."
      return
    end

    session[:user_email] = email
    session[:user_name] = profile[:name]
    redirect_to root_path, notice: "Signed in as #{email}."
  end

  def apple_callback
    stored_state = cookies[:apple_oauth_state]
    if params[:state].blank? || params[:state] != stored_state
      redirect_to login_path, alert: "Invalid OAuth state. Please try again."
      return
    end
    cookies.delete(:apple_oauth_state)

    if params[:error].present?
      redirect_to login_path, alert: "Apple authentication was canceled or failed."
      return
    end

    token_data = exchange_apple_code(params[:code])
    unless token_data && token_data["id_token"]
      redirect_to login_path, alert: "Apple did not return an ID token."
      return
    end

    claims = decode_jwt_payload(token_data["id_token"])
    unless claims
      redirect_to login_path, alert: "Could not decode Apple ID token."
      return
    end

    email = claims["email"]&.downcase
    unless email && email_allowed?(email)
      reset_session
      redirect_to login_path, alert: "Access denied: #{email || 'no verified email'} is not on the allowlist."
      return
    end

    name = apple_user_name(params[:user]) || email
    session[:user_email] = email
    session[:user_name] = name
    redirect_to root_path, notice: "Signed in as #{email}."
  end

  def failure
    redirect_to login_path, alert: "Authentication failed."
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "Signed out."
  end

  private

  # --- Shared ---

  def email_allowed?(email)
    return false unless email
    email = email.downcase
    email_allowlist.any? do |pattern|
      pattern = pattern.downcase
      pattern.start_with?("*@") ? email.end_with?("@#{pattern[2..]}") : email == pattern
    end
  end

  def email_allowlist
    ENV.fetch("EMAIL_ALLOWLIST", "").split(",").map(&:strip).reject(&:empty?)
  end

  # --- GitHub ---

  def github_client_id
    ENV.fetch("GITHUB_CLIENT_ID", "")
  end

  def exchange_code_for_token(code)
    return if code.blank?

    res = Net::HTTP.post(
      GITHUB_TOKEN_URL,
      URI.encode_www_form(
        client_id: github_client_id,
        client_secret: ENV.fetch("GITHUB_CLIENT_SECRET", ""),
        code: code,
        redirect_uri: ENV.fetch("GITHUB_CALLBACK_URL", "")
      ),
      "Accept" => "application/json"
    )
    unless res.is_a?(Net::HTTPSuccess)
      Rails.logger.error("GitHub token endpoint returned #{res.code}: #{res.body}")
      return nil
    end
    JSON.parse(res.body)["access_token"]
  rescue JSON::ParserError => e
    Rails.logger.error("GitHub token parse error: #{e.message}")
    nil
  rescue SocketError, Errno::ECONNREFUSED => e
    Rails.logger.error("GitHub token connection error: #{e.message}")
    nil
  end

  def fetch_github_user(token)
    data = github_get(GITHUB_USER_URL, token)
    return nil unless data.is_a?(Hash)

    email = data["email"]
    unless email
      emails = github_get(GITHUB_EMAILS_URL, token)
      primary = emails&.find { |e| e["primary"] && e["verified"] }
      email = primary && primary["email"]
    end

    { name: data["name"] || data["login"], email: email }
  end

  def github_get(url, token)
    req = Net::HTTP::Get.new(url)
    req["Authorization"] = "Bearer #{token}"
    req["Accept"] = "application/json"
    res = Net::HTTP.start(url.hostname, url.port, use_ssl: true) { |http| http.request(req) }
    unless res.is_a?(Net::HTTPSuccess)
      Rails.logger.error("GitHub API #{url} returned #{res.code}: #{res.body}")
      return nil
    end
    JSON.parse(res.body)
  rescue JSON::ParserError => e
    Rails.logger.error("GitHub API parse error for #{url}: #{e.message}")
    nil
  rescue SocketError, Errno::ECONNREFUSED => e
    Rails.logger.error("GitHub API connection error for #{url}: #{e.message}")
    nil
  end

  # --- Apple ---

  def apple_client_id
    ENV.fetch("APPLE_CLIENT_ID", "")
  end

  def apple_configured?
    return false if apple_client_id.blank?
    inline = ENV.fetch("APPLE_PRIVATE_KEY", "").strip
    return true if inline.present?

    path = ENV["APPLE_PRIVATE_KEY_FILE"]
    path.present? && File.exist?(path)
  end

  def apple_scopes
    scopes = ENV.fetch("APPLE_SCOPES", "").gsub(/["']/, "")
    scopes.strip.present? ? scopes.strip : "name email"
  end

  def apple_private_key
    return @apple_private_key if defined?(@apple_private_key)

    key_content = nil
    inline = ENV.fetch("APPLE_PRIVATE_KEY", "").strip
    if inline.present?
      key_content = inline.gsub("\\n", "\n")
    elsif ENV["APPLE_PRIVATE_KEY_FILE"].present?
      key_content = File.read(ENV["APPLE_PRIVATE_KEY_FILE"]) if File.exist?(ENV["APPLE_PRIVATE_KEY_FILE"])
    end

    @apple_private_key = key_content ? OpenSSL::PKey.read(key_content) : nil
  rescue OpenSSL::PKey::PKeyError => e
    Rails.logger.error("Failed to load Apple private key: #{e.message}")
    @apple_private_key = nil
  end

  def apple_client_secret_jwt
    key = apple_private_key
    return nil unless key

    header = { alg: "ES256", kid: ENV.fetch("APPLE_KEY_ID", ""), typ: "JWT" }
    now = Time.now.to_i
    payload = {
      iss: ENV.fetch("APPLE_TEAM_ID", ""),
      iat: now,
      exp: now + 3600,
      aud: "https://appleid.apple.com",
      sub: apple_client_id
    }

    signing_input = "#{base64url_encode(header.to_json)}.#{base64url_encode(payload.to_json)}"
    der_sig = key.sign(OpenSSL::Digest::SHA256.new, signing_input)
    raw_sig = der_to_ecdsa_raw(der_sig, key)
    "#{signing_input}.#{base64url_encode(raw_sig)}"
  end

  def der_to_ecdsa_raw(der_sig, key)
    asn1 = OpenSSL::ASN1.decode(der_sig)
    r = asn1.value[0].value
    s = asn1.value[1].value
    n = (key.group.order.num_bits + 7) / 8
    r_hex = r.to_s(16).rjust(n * 2, "0")
    s_hex = s.to_s(16).rjust(n * 2, "0")
    [ r_hex + s_hex ].pack("H*")
  end

  def exchange_apple_code(code)
    return nil if code.blank?

    secret = apple_client_secret_jwt
    return nil unless secret

    res = Net::HTTP.post(
      APPLE_TOKEN_URL,
      URI.encode_www_form(
        grant_type: "authorization_code",
        code: code,
        redirect_uri: ENV.fetch("APPLE_CALLBACK_URL", ""),
        client_id: apple_client_id,
        client_secret: secret
      )
    )
    unless res.is_a?(Net::HTTPSuccess)
      Rails.logger.error("Apple token endpoint returned #{res.code}: #{res.body}")
      return nil
    end
    JSON.parse(res.body)
  rescue JSON::ParserError => e
    Rails.logger.error("Apple token parse error: #{e.message}")
    nil
  rescue SocketError, Errno::ECONNREFUSED => e
    Rails.logger.error("Apple token connection error: #{e.message}")
    nil
  end

  def decode_jwt_payload(jwt)
    parts = jwt.split(".")
    return nil unless parts.length >= 2
    JSON.parse(Base64.urlsafe_decode64(parts[1]))
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def apple_user_name(user_param)
    return nil if user_param.blank?
    data = JSON.parse(user_param)
    name = data["name"]
    return nil unless name
    "#{name['firstName']} #{name['lastName']}".strip
  rescue JSON::ParserError
    nil
  end

  def base64url_encode(data)
    Base64.urlsafe_encode64(data, padding: false)
  end
end
