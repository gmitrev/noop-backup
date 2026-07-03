require "aws-sdk-s3"

module NoopBackup::Stores
  class S3
    attr_accessor :bucket, :region, :access_key_id, :secret_access_key

    def initialize
      @bucket = ENV["AWS_S3_BUCKET"]
      @region = ENV["AWS_REGION"]
      @access_key_id = ENV["AWS_ACCESS_KEY_ID"]
      @secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
    end

    # Prefer Aws::S3::TransferManager for streaming uploads if available.
    # Aws::S3::Resource.upload_stream is deprecated in newer versions
    def backup!(key, stream)
      validate!

      bytes = 0
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      if defined?(Aws::S3::TransferManager)
        manager = Aws::S3::TransferManager.new(client: s3_client)

        manager.upload_stream(bucket:, key: key, part_size: 8 * 1024 * 1024, thread_count: 2) do |s3_stream|
          bytes = IO.copy_stream(stream, s3_stream)
        end
      else
        object = Aws::S3::Resource.new(client: s3_client).bucket(bucket).object(key)

        object.upload_stream(part_size: 8 * 1024 * 1024, thread_count: 2) do |s3_stream|
          bytes = IO.copy_stream(stream, s3_stream)
        end
      end

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      Result.new(success: true, store: :s3, bytes:, key:, duration:)
    end

    def validate!
      # TODO: Check for all settings
      raise ConfigurationError, "bucket is not configured" if bucket.to_s.empty?
    end

    def cleanup!(key)
      s3_client.delete_object(bucket:, key: key)
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
