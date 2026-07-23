require "aws-sdk-s3"

module BoringBackup::Stores
  class S3 < Store
    DEFAULT_STORAGE_CLASS = :standard_ia

    STORAGE_CLASSES = %i[
      standard
      standard_ia
      onezone_ia
      intelligent_tiering
      glacier_ir
      glacier
      deep_archive
      reduced_redundancy
      express_onezone
      outposts
      snow
    ].freeze

    attr_accessor :bucket, :region, :access_key_id, :secret_access_key, :part_size, :thread_count, :endpoint
    attr_writer :storage_class

    def initialize
      @region = ENV["AWS_REGION"]
      @access_key_id = ENV["AWS_ACCESS_KEY_ID"]
      @secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"]
      @part_size = ENV.fetch("BB_S3_PART_SIZE", 8 * 1024 * 1024).to_i
      @thread_count = ENV.fetch("BB_S3_THREAD_COUNT", 2).to_i
      @storage_class = ENV.fetch("BB_S3_STORAGE_CLASS", DEFAULT_STORAGE_CLASS)
    end

    def storage_class
      value = @storage_class.to_s.strip.downcase

      value.empty? ? nil : value.to_sym
    end

    def name = :s3

    def description
      [bucket.to_s.empty? ? "no bucket" : "#{name}://#{bucket}", region].compact.join(" ")
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

        manager.upload_stream(bucket:, key: key, **upload_options) do |s3_stream|
          bytes = IO.copy_stream(stream, s3_stream)
        end
      else
        object = Aws::S3::Resource.new(client: s3_client).bucket(bucket).object(key)

        object.upload_stream(**upload_options) do |s3_stream|
          bytes = IO.copy_stream(stream, s3_stream)
        end
      end

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      if config.min_size && bytes < config.min_size.to_i
        raise BoringBackup::DumpTooSmallError, "backup too small: #{BoringBackup.utils.human_size(bytes)} < min_size (#{BoringBackup.utils.human_size(config.min_size)})"
      end

      Result.new(success: true, store: name, bytes:, key:, duration:)
    rescue => e
      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      cleanup!(key) if upload_attempted

      Result.new(success: false, error: e, store: name, bytes:, key:, duration:)
    end

    def validate!
      raise BoringBackup::ConfigurationError, "bucket is not configured" if bucket.to_s.empty?

      if access_key_id.to_s.empty? != secret_access_key.to_s.empty?
        raise BoringBackup::ConfigurationError,
          "access_key_id and secret_access_key must both be set, or both left blank to use the default AWS credential chain"
      end

      if storage_class && !STORAGE_CLASSES.include?(storage_class)
        raise BoringBackup::ConfigurationError,
          "unknown storage class: #{storage_class.inspect} (expected one of: #{STORAGE_CLASSES.map(&:inspect).join(", ")}, or nil to use the bucket default)"
      end
    end

    def cleanup!(key)
      s3_client.delete_object(bucket:, key:)
    rescue => e
      warn "Failed to clean up partial upload #{key}: #{e.message}"
    end

    private

    def upload_options
      options = {part_size:, thread_count:}
      options[:storage_class] = storage_class.to_s.upcase if storage_class
      options
    end

    def s3_client
      @_s3_client ||= Aws::S3::Client.new(**s3_config)
    end

    def s3_config
      {
        endpoint:,
        region:,
        access_key_id:,
        secret_access_key:
      }.compact
    end
  end
end
