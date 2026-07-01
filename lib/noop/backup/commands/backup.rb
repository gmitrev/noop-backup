require "aws-sdk-s3"
require "open3"

module Noop::Backup::Commands
  class Backup
    def self.execute
      new.execute
    end

    def initialize
      @key = [config.prefix, Time.now.utc.strftime("%Y%m%dT%H%M%SZ")].join("/")
      @bytes = 0
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
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

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started

      if config.min_size && @bytes.to_i < config.min_size.to_i
        s3_client.delete_object(bucket: config.bucket, key: @key)

        raise "backup too small: #{human_size(@bytes)} < min_size (#{human_size(config.min_size)})"
      end

      config.notify(success_message(duration))
    rescue => e
      config.notify("❌ Backup failed: #{e.message}")
    end

    private

    def config
      @config ||= Noop::Backup.configuration
    end

    def s3_client
      @_s3_client ||= Aws::S3::Client.new(region: config.region)
    end

    # Prefer Aws::S3::TransferManager for streaming uploads if available.
    # Aws::S3::Resource.upload_stream is deprecated in newer versions
    def upload(stdout)
      if defined?(Aws::S3::TransferManager)
        manager = Aws::S3::TransferManager.new(client: s3_client)

        manager.upload_stream(bucket: config.bucket, key: @key, part_size: 8 * 1024 * 1024, thread_count: 2) do |s3_stream|
          @bytes = IO.copy_stream(stdout, s3_stream)
        end
      else
        object = Aws::S3::Resource.new(region: config.region).bucket(config.bucket).object(@key)

        object.upload_stream(part_size: 8 * 1024 * 1024, thread_count: 2) do |s3_stream|
          @bytes = IO.copy_stream(stdout, s3_stream)
        end
      end
    end

    def human_size(bytes)
      units = %w[B KB MB GB TB]
      size = bytes.to_f
      i = 0
      while size >= 1024 && i < units.size - 1
        size /= 1024
        i += 1
      end
      format("%.1f %s", size, units[i])
    end

    def success_message(duration)
      "✅ #{config.pg_env["PGDATABASE"]} backed up successfully — " \
        "#{human_size(@bytes)} in #{duration.round(1)}s → #{config.bucket}/#{@key}"
    end
  end
end
