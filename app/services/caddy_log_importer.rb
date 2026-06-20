require "json"
require "zlib"

class CaddyLogImporter
  ANSI_RE = /\x1b\[[0-9;]*m/.freeze

  Result = Struct.new(:access_count, :error_count, :skipped, keyword_init: true)

  def self.import_directory(dir)
    new(dir).import
  end

  def self.reset
    AccessLog.delete_all
    ErrorLog.delete_all
    ImportedFile.delete_all
  end

  def initialize(dir)
    @dir = dir
  end

  def import
    result = Result.new(access_count: 0, error_count: 0, skipped: 0)

    Dir.glob("#{@dir}/*.log.gz").each { |f| process_gz_file(f, result) }
    Dir.glob("#{@dir}/*.log").each { |f| process_active_file(f, result) }

    result
  end

  private

  def process_gz_file(path, result)
    record = ImportedFile.find_or_create_by!(filename: path)

    if record.completed
      result.skipped += 1
      return
    end

    is_error = File.basename(path).include?("error")
    io = Zlib::GzipReader.open(path)
    batch = []
    batch_size = 500

    io.each_line do |line|
      row = is_error ? parse_error_line(line) : parse_access_line(line)
      if row
        batch << row
        if batch.size >= batch_size
          insert_batch(batch, is_error, result)
          batch.clear
        end
      else
        result.skipped += 1
      end
    end

    insert_batch(batch, is_error, result) if batch.any?
  ensure
    io&.close
    record.update!(completed: true, last_imported_at: Time.current)
  end

  def process_active_file(path, result)
    record = ImportedFile.find_or_create_by!(filename: path)
    offset = record.byte_offset

    file_size = File.size(path)
    return if offset >= file_size

    is_error = File.basename(path).include?("error")
    batch = []
    batch_size = 500
    bytes_processed = 0

    File.open(path, "r") do |f|
      f.seek(offset)
      content = f.read
      return if content.nil? || content.empty?

      last_newline = content.rindex("\n")
      return if last_newline.nil?

      processable = content[0..last_newline]
      bytes_processed = processable.bytesize

      processable.each_line do |line|
        row = is_error ? parse_error_line(line) : parse_access_line(line)
        if row
          batch << row
          if batch.size >= batch_size
            insert_batch(batch, is_error, result)
            batch.clear
          end
        else
          result.skipped += 1
        end
      end
    end

    insert_batch(batch, is_error, result) if batch.any?

    record.update!(byte_offset: offset + bytes_processed, last_imported_at: Time.current)
  end

  def insert_batch(batch, is_error, result)
    now = Time.current.iso8601
    rows = batch.map { |r| r.merge(created_at: now, updated_at: now) }

    if is_error
      ErrorLog.insert_all!(rows)
      result.error_count += batch.size
    else
      AccessLog.insert_all!(rows)
      result.access_count += batch.size
    end
  end

  def split_line(line)
    parts = line.split("\t")
    return nil if parts.length < 5

    {
      timestamp: Time.strptime(parts[0], "%Y/%m/%d %H:%M:%S.%L").iso8601,
      level: parts[1].gsub(ANSI_RE, ""),
      source: parts[2],
      message: parts[3],
      json_str: parts[4..].join("\t")
    }
  end

  def parse_access_line(line)
    parts = split_line(line)
    return nil unless parts

    data = JSON.parse(parts[:json_str])
    req = data["request"] || {}
    tls = req["tls"] || {}
    headers = req["headers"] || {}

    {
      timestamp: parts[:timestamp],
      remote_ip: req["remote_ip"],
      client_ip: req["client_ip"],
      method: req["method"],
      host: req["host"],
      uri: req["uri"]&.truncate(2000),
      status: data["status"],
      size: data["size"],
      bytes_read: data["bytes_read"],
      duration: data["duration"],
      proto: req["proto"],
      user_agent: header_value(headers, "User-Agent")&.truncate(1000),
      referer: header_value(headers, "Referer")&.truncate(1000),
      tls_version: tls["version"],
      tls_proto: tls["proto"],
      server_name: tls["server_name"],
      request_id: header_value(headers, "X-Request-Id")
    }
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def parse_error_line(line)
    parts = split_line(line)
    return nil unless parts

    data = JSON.parse(parts[:json_str])
    req = data["request"] || {}

    {
      timestamp: parts[:timestamp],
      level: parts[:level],
      source: parts[:source],
      message: parts[:message],
      remote_ip: req["remote_ip"],
      method: req["method"],
      host: req["host"],
      uri: req["uri"]&.truncate(2000),
      status: data["status"],
      duration: data["duration"],
      err_id: data["err_id"],
      err_trace: data["err_trace"]
    }
  rescue JSON::ParserError, ArgumentError
    nil
  end

  def header_value(headers, key)
    values = headers[key]
    return nil unless values&.any?
    values.first
  end
end
