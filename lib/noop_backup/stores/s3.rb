require "aws-sdk-s3"

module NoopBackup::Stores
  class S3 < Store
    attr_accessor :bucket, :region, :access_key_id, :secret_access_key, :part_size, :thread_count

    def initialize
      @bucket = ENV["AWS_S3_BUCKET"]
      @region = ENV["AWS_REGION"]
      @access_key_id = ENV["AWS_ACCESS_KEY_ID"]
      @secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
      @part_size = ENV.fetch("NBU_S3_PART_SIZE", 8 * 1024 * 1024).to_i
      @thread_count = ENV.fetch("NBU_S3_THREAD_COUNT", 2).to_i
    end

    # Prefer Aws::S3::TransferManager for streaming uploads if available.
    # Aws::S3::Resource.upload_stream is deprecated in newer versions
    def backup!(key, stream)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      bytes = 0

      validate!

      upload_attempted = true

      if defined?(Aws::S3::TransferManager)
        manager = Aws::S3::TransferManager.new(client: s3_client)

        manager.upload_stream(bucket:, key: key, part_size:, thread_count:) do |s3_stream|
          bytes = IO.copy_stream(stream, s3_stream)
        end
      else
        object = Aws::S3::Resource.new(client: s3_client).bucket(bucket).object(key)

        object.upload_stream(part_size:, thread_count:) do |s3_stream|
          bytes = IO.copy_stream(stream, s3_stream)
        end
      end

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      if config.min_size && bytes < config.min_size.to_i
        raise NoopBackup::DumpTooSmallError, "backup too small: #{NoopBackup.utils.human_size(bytes)} < min_size (#{NoopBackup.utils.human_size(config.min_size)})"
      end

      Result.new(success: true, store: :s3, bytes:, key:, duration:)
    rescue => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      cleanup!(key) if upload_attempted

      Result.new(success: false, error: e, store: :s3, bytes:, key:, duration:)
    end

    def validate!
      raise NoopBackup::ConfigurationError, "bucket is not configured" if bucket.to_s.empty?

      if access_key_id.to_s.empty? != secret_access_key.to_s.empty?
        raise NoopBackup::ConfigurationError,
          "access_key_id and secret_access_key must both be set, or both left blank to use the default AWS credential chain"
      end
    end

    def cleanup!(key)
      s3_client.delete_object(bucket:, key:)
    rescue => e
      warn "Failed to clean up partial upload #{key}: #{e.message}"
    end

    private

    def s3_client
      @_s3_client ||= Aws::S3::Client.new(**s3_config)
    end

    def s3_config
      {
        region: region,
        access_key_id: access_key_id,
        secret_access_key: secret_access_key
      }.compact
    end
  end
end
