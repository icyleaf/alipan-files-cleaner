# frozen_string_literal: true

require "faraday"

class AliyunDrive
  ENDPOINT = "https://api.aliyundrive.com"

  attr_reader :default_drive_id

  def initialize(refresh_token:, logger:, access_token: nil, endpoint: ENDPOINT)
    @refresh_token = refresh_token
    @logger = logger
    @endpoint = endpoint

    @expired_time = nil
    @default_drive_id = nil
  end

  def user_info
    response = connection.post("https://user.aliyundrive.com/v2/user/get", {})
    case response.status
    when 200
      response.body
    when 401
      raise NotAuthorizedError, response.body
    else
      raise ResponseError, response.body
    end
  end

  def disk_capacity
    _post("/adrive/v1/user/driveCapacityDetails", {})
  end

  def files(folder_id, drive_id: nil)
    drive_id ||= @default_drive_id

    _post("/adrive/v2/file/list", {
      "drive_id": drive_id,
      "parent_file_id": folder_id
    })
  end

  def file_path(file_id, drive_id: nil)
    drive_id ||= @default_drive_id

    _post("/adrive/v1/file/get_path", {
      "drive_id": drive_id,
      "file_id": file_id
    })
  end

  def delete_file(file_id, drive_id: nil)
    drive_id ||= @default_drive_id

    response = _post("/v3/batch", {
      requests: [
        {
          body: {
            drive_id: drive_id,
            file_id: file_id
          },
          headers: {
            "Content-Type": "application/json"
          },
          id: file_id,
          method: "POST",
          url: "/file/delete"
        }
      ],
      resource: "file"
    })

    response["responses"].each do |file_response|
      next unless file_response["id"] == file_id

      return true if file_response["status"] == 204
      return file_response
    end

    false
  end

  def update_default_drive_id
    data = user_info
    @default_drive_id = data["resource_drive_id"] || data["default_drive_id"]
  end

  def access_token
    if @access_token.nil? || @access_token.empty? || expired_access_token?
      @access_token = update_access_token
    end

    @access_token
  end

  def expired_access_token?
    return true if @expired_time.nil?

    expired_time < Time.now
  end

  class ResponseError < StandardError; end
  class NotAuthorizedError < ResponseError; end

  private

  def _post(path, *params)
    response = connection.post(path, *params)

    handle_response(response)
  end

  def handle_response(response)
    case response.status
    when 200
      response.body
    when 401
      raise NotAuthorizedError, response.body
    else
      raise ResponseError, response.body
    end
  end

  def access_token
    @access_token ||= update_access_token
  end

  def update_access_token
    response = Faraday.post("https://api.aliyundrive.com/v2/account/token") do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = {
        grant_type: "refresh_token",
        refresh_token: @refresh_token
      }.to_json
    end

    body = JSON.parse(response.body)

    @refresh_token = body["refresh_token"]
    @expired_time = Time.at(Time.now.to_i + (body["expires_in"] || 0))

    body["access_token"]
  end

  def uri(path)
    "#{@endpoint}/#{path}"
  end

  def connection
    @connection ||= Faraday.new(url: @endpoint) do |builder|
      builder.response :logger, nil, { bodies: true, log_level: :debug } if ENV["VERBOSE_MODE"] == "true"
      builder.proxy = "http://127.0.0.1:9091" if ENV["PROXY_MODE"] == "true"

      builder.request :authorization, 'Bearer', access_token
      builder.request :json
      builder.response :json
    end
  end
end
