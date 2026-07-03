require "open3"

module NoopBackup::Commands
  class Backup
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
      @results = []
    end

    def execute
      commands = [
        [config.pg_env, "pg_dump", "--format=custom", "--no-owner"]
      ]

      commands << ["pv", "-btra"] if system("which", "pv", out: File::NULL, err: File::NULL)

      sinks = config.stores.map do |store|
        reader, writer = IO.pipe(binmode: true)

        thread = Thread.new do
          @results << store.backup!(@key, reader)
        ensure
          reader.close
        end

        Sink.new(writer:, thread:)
      end

      sinks_fanout = NoopBackup::Tee.new(sinks.map(&:writer))

      Open3.pipeline_r(*commands) do |last_stdout, wait_threads|
        IO.copy_stream(last_stdout, sinks_fanout)

        sinks.each(&:close)
        sinks.each(&:join)

        raise "pipeline failed" unless wait_threads.all? { |t| t.value.success? }
      end

      report_results

      @results
    end

    private

    def config
      @config ||= NoopBackup.configuration
    end

    def report_results
      @results.each do |result|
        config.notify result.message
      end
    end
  end
end
