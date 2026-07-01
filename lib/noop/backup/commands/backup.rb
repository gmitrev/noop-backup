require "aws-sdk-s3"
require "open3"

module Noop::Backup::Commands
  class Backup
    def self.execute
      new.execute
    end

    def initialize
      @key = [config.prefix, Time.now.utc.strftime("%Y%m%dT%H%M%SZ")].join("/")
    end

    def config
      @config ||= Noop::Backup.configuration
    end

    def execute
      commands = [
        [config.pg_env, "pg_dump", "--format=custom", "--no-owner"]
      ]

      commands << ["pv", "-btra"] if system("which", "pv", out: File::NULL, err: File::NULL)

      Open3.pipeline_r(*commands) do |last_stdout, wait_threads|
        upload(last_stdout)

        raise "pipeline failed" unless wait_threads.all? { |t| t.value.success? }
      end

      config.notify("✅ Backup completed: #{@key}")
    rescue => e
      config.notify("❌ Backup failed: #{e.message}")
    end

    # Prefer Aws::S3::TransferManager for streaming uploads if available.
    # Aws::S3::Resource.upload_stream is deprecated in newer versions
    def upload(stdout)
      if defined?(Aws::S3::TransferManager)
        client = Aws::S3::Client.new(region: config.region)

        manager = Aws::S3::TransferManager.new(client:)

        manager.upload_stream(bucket: config.bucket, key: @key, part_size: 8 * 1024 * 1024, thread_count: 2) do |s3_stream|
          IO.copy_stream(stdout, s3_stream)
        end
      else
        object = Aws::S3::Resource.new(region: config.region).bucket(config.bucket).object(@key)

        object.upload_stream(part_size: 8 * 1024 * 1024, thread_count: 2) do |s3_stream|
          IO.copy_stream(stdout, s3_stream)
        end
      end
    end
  end
end
