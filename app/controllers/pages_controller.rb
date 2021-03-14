class PagesController < ApplicationController
  before_action :set_infusionsoft_api_tokens, only: [:settings, :refresh]
  def home
  end

  def settings
    @infusionsoft_auth_url  = ENV.fetch('INFUSIONSOFT_AUTH_URL', 'https://accounts.infusionsoft.com/app/oauth/authorize') + '?'
    @infusionsoft_auth_url += 'client_id=' + ENV['INFUSIONSOFT_CLIENT_ID']
    @infusionsoft_auth_url += '&redirect_uri=' + request.base_url + '/auth/infusionsoft/callback'
    @infusionsoft_auth_url += '&response_type=code'
    @infusionsoft_auth_url += '&scope=full'
  end

  def auth
    @provider = params[:provider]
    @code = params[:code]

    request_access_token

    redirect_to settings_path
  end

  def refresh
    refresh_access_token
    redirect_to settings_path
  end

  def up
    Redis.current.ping
    ActiveRecord::Base.connection.execute("SELECT 1")

    head :ok
  end

  private

  def request_access_token
    body = {
      client_id: ENV.fetch('INFUSIONSOFT_CLIENT_ID'),
      client_secret: ENV.fetch('INFUSIONSOFT_CLIENT_SECRET'),
      code: @code,
      grant_type: 'authorization_code',
      redirect_uri: request.base_url + '/auth/infusionsoft/callback'
    }

    @response = Faraday.post(ENV.fetch('INFUSIONSOFT_TOKEN_URL', 'https://api.infusionsoft.com/token'), body, 'Content-Type' => 'application/x-www-form-urlencoded')

    logger.info 'Request access token'
    logger.info @response.status
    logger.info @response.headers
    logger.info @response.body

    store_tokens
  end

  def refresh_access_token
    body = {
      grant_type: 'refresh_token',
      refresh_token: cookies[:refresh_token]
    }

    @response = Faraday.post(ENV.fetch('INFUSIONSOFT_TOKEN_URL', 'https://api.infusionsoft.com/token'), body, 'Authorization' => "Basic #{ Base64.strict_encode64 ENV['INFUSIONSOFT_CLIENT_ID'] + ':' + ENV['INFUSIONSOFT_CLIENT_SECRET'] }")

    logger.info 'Refresh access token'
    logger.info @response.status
    logger.info @response.headers
    logger.info @response.body

    store_tokens
  end

  def set_infusionsoft_api_tokens
    @access_token  = cookies[:access_token]
    @expires_in    = cookies[:expires_in]
    @refresh_token = cookies[:refresh_token]
  end

  def store_tokens
    return unless @response.status == 200

    body = JSON.parse(@response.body)

    cookies[:access_token]  = body['access_token']
    cookies[:expires_in]    = body['expires_in']
    cookies[:refresh_token] = body['refresh_token']
  end
end
