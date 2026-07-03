require "open3"

module NoopBackup::Commands
  CommandResult = Struct.new(:status, :error, :store_results, keyword_init: true) do
    def report
      if error
        # TODO: do not go through configuration
        NoopBackup.configuration.notify "❌ Fatal error: #{error.message}"
      else
        store_results.each do |result|
          # TODO: do not go through configuration
          NoopBackup.configuration.notify result.message
        end
      end
    end
  end

  class Backup
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
      @store_results = []
    end

    def execute
      raise NoopBackup::ConfigurationError, "No backup stores resistered" if config.stores.empty?

      # TODO: Validate all stores. Report any errors and exit early if any validation fails
      #
      commands = [
        [config.pg_env, "pg_dump", "--format=custom", "--no-owner"]
      ]

      commands << ["pv", "-btra"] if system("which", "pv", out: File::NULL, err: File::NULL)

      sinks = config.stores.map do |store|
        reader, writer = IO.pipe(binmode: true)

        thread = Thread.new do
          @store_results << store.backup!(@key, reader)
        ensure
          reader.close
        end

        NoopBackup::Tee::Sink.new(writer:, thread:)
      end

      sinks_fanout = NoopBackup::Tee.new(sinks)

      Open3.pipeline_r(*commands) do |last_stdout, wait_threads|
        IO.copy_stream(last_stdout, sinks_fanout)

        sinks.each(&:close)
        sinks.each(&:join)

        raise "pipeline failed" unless wait_threads.all? { |t| t.value.success? }
      end

      CommandResult.new(
        status: @store_results.all?(&:success) ? :success : :partial_success,
        store_results: @store_results
      )
    rescue => error
      CommandResult.new(status: :failure, error:)
    end

    private

    def config
      @config ||= NoopBackup.configuration
    end
  end
end
