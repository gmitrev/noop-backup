require "open3"

module NoopBackup::Commands
  class Backup
    Result = Struct.new(:status, keyword_init: true) do
    end

    Sink = Struct.new(:writer, :thread, keyword_init: true) do
      def close
        writer.close
      end

      def join
        thread.join
      end
    end

    def self.execute
      new.execute
    end

    def initialize
      now = Time.now.utc
      @key = [
        config.prefix,
        config.pg_env["PGDATABASE"],
        now.strftime("%Y"),
        now.strftime("%m"),
        "#{now.strftime("%d-%H-%M-%S-%L")}.dump"
      ].compact.join("/")
      @bytes = 0
      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    def execute
      commands = [
        [config.pg_env, "pg_dump", "--format=custom", "--no-owner"]
      ]

      commands << ["pv", "-btra"] if system("which", "pv", out: File::NULL, err: File::NULL)

      sinks = config.stores.map do |store|
        reader, writer = IO.pipe(binmode: true)

        thread = Thread.new do
          store.backup!(@key, reader)
        ensure
          reader.close
        end

        Sink.new(writer:, thread:)
      end

      sinks_fanout = NoopBackup::Tee.new(sinks.map(:writer))

      Open3.pipeline_r(*commands) do |last_stdout, wait_threads|
        @bytes = IO.copy_stream(last_stdout, sinks_fanout)

        sinks.each(&:close)
        sinks.each(&:join)

        raise "pipeline failed" unless wait_threads.all? { |t| t.value.success? }
      end

      duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - @started

      if config.min_size && @bytes.to_i < config.min_size.to_i
        raise "backup too small: #{human_size(@bytes)} < min_size (#{human_size(config.min_size)})"
      end

      config.notify(success_message(duration))
    rescue => e
      config.stores.each do |store|
        store.cleanup!(@key)
      end

      config.notify("❌ Backup failed: #{e.message}")

      raise
    end

    private

    def config
      @config ||= NoopBackup.configuration
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
      # TODO: Allow stores to plug their own shit
      "✅ #{config.pg_env["PGDATABASE"]} backed up successfully — " \
        "#{human_size(@bytes)} in #{duration.round(1)}s → /#{@key}"
    end
  end
end
