# frozen_string_literal: true

require_relative "aliyundrive"
require "logger"
require "uri"

class Runner
  VERSION = "0.2.1"

  def self.run
    new.run
  end

  def run
    logger.info "Starting alipan resources runner ..."
    logger.info "cli v#{VERSION}, run_mode: #{run_mode}, dry_mode: #{dry_mode}"
    client.update_default_drive_id

    run_loop do
      show_disk_capacity

      logger.info "Fetching files from drive_id #{client.default_drive_id} "
      removed_files = 0
      alipan_files = client.files(folder_id).dig("items") || {}
      if alipan_files.empty?
        logger.info "Not found files, skipped."
        break
      end

      logger.info "Prepare to delete #{alipan_files.size} file(s) ..."
      alipan_files.each do |file|
        logger.info "Deleting #{file["type"]}: #{file["name"]} (#{binary_to_human(file["size"])})"
        file_id = file["file_id"]
        file_path = client.file_path(file_id) # NOTE: 可能是为了仿真手机操作
        removed_files += file["size"]
        next if dry_mode

        deleted_file = client.delete_file(file_id)
        case deleted_file
        when FalseClass
          logger.error("Delete file failed with unknown error: #{file_id} - #{file["name"]}")
        when Hash
          logger.error("Delete file failed with response: #{file_id} - #{file["name"]} - #{deleted_file}")
        end
      end

      logger.info "Result: cleaned disk #{binary_to_human(removed_files)}."
    end
  rescue AliyunDrive::NotAuthorizedError => e
    logger.error "Invalid refresh token, Try to fetch a new one:  https://aliyundriver-refresh-token.vercel.app/"
    exit
  rescue AliyunDrive::ResponseError => e
    logger.error "Unknown response error: #{e.message}"
    exit
  rescue URI::BadURIError => e
    logger.error "Invalid nomad endpoint: #{client.endpoint}. it must be a valid URI: http(s)://nomad.example.com or http(s)://127.0.0.1:4646"
    exit
  rescue SignalException => e
    logger.error "Received signal #{e.class}: #{e.signo}, exiting runner..."
    exit
  end

  private

  def run_loop(&block)
    count = 0
    loop do
      block.call

      exit if oneshort?

      logger.info "Waiting next loop ... (#{interval} seconds)"
      sleep(interval)
      count += 1
    end
  end

  def show_disk_capacity
    disk_capacity = client.disk_capacity
    total = disk_capacity["drive_total_size"]
    used = disk_capacity["drive_used_size"]
    free = total - used

    total_h = binary_to_human(total)
    used_h = binary_to_human(used)
    free_h = binary_to_human(free)

    logger.info "Drive disk in total: #{total_h}, used: #{used_h}, free: #{free_h}"
  end

  def folder_id
    @folder_id ||= -> {
      endpoint = ENV.fetch("ALIPAN_FOLDER_ID") do
        logger.error "Missing envoriment variable: ALIPAN_FOLDER_ID"
        exit
      end

      ENV["ALIPAN_FOLDER_ID"]
    }.call
  end

  def binary_to_human(bytes)
    sizes = ['B', 'KB', 'MB', 'GB', 'TB']
    index = 0
    while bytes >= 1024 && index < sizes.length - 1
      bytes /= 1024.0
      index += 1
    end
    "#{bytes.round(2)} #{sizes[index]}"
  end

  def oneshort?
    run_mode == :oneshort
  end

  def run_mode
    interval.zero? ? :oneshort : :interval
  end

  def interval
    @interval ||= ENV.fetch("ALIPAN_RUNNER_INTERVAL", "0").to_i
  end

  def dry_mode
    ENV["DRY_MODE"] == "true"
  end

  def logger
    @logger ||= Logger.new(STDOUT, 'daily', level: ENV.fetch('LOGGER_LEVEL', "info").to_sym)
  end

  def client
    @client ||= -> {
      endpoint = ENV.fetch("ALIPAN_REFRESH_TOKEN") do
        logger.error "Missing envoriment variable: ALIPAN_REFRESH_TOKEN"
        exit
      end

      refresh_token = ENV["ALIPAN_REFRESH_TOKEN"]
      AliyunDrive.new(refresh_token: refresh_token, logger: logger)
    }.call
  end
end
