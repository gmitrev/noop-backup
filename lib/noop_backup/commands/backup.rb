require "open3"

module NoopBackup::Commands
  CommandResult = Struct.new(:error, :store_results, keyword_init: true) do
    def success?
      status == :success
    end

    def status
      return :error if error
      return :error if store_results.blank? || store_results.none?(&:success)
      return :success if store_results.all?(&:success)
      :partial_success
    end

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
    def self.execute(report: true)
      result = new.execute

      result.report if report

      result
    end

    def initialize
      @store_results = []
      @key = generate_key
    end

    def execute
      perform_sanity_check!

      commands = [
        [config.pg_env, "pg_dump", "--format=custom", "--no-owner"]
      ]

      # Pipe pg_dump through pv if installed for a basic progress report
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

      CommandResult.new(store_results: @store_results)
    rescue => error
      CommandResult.new(error:)
    end

    private

    # 1. Check if any stores are registered.
    # 2. Make sure **all** stores have a valid configuration
    def perform_sanity_check!
      raise NoopBackup::ConfigurationError, "No backup stores registered" if config.stores.empty?

      config.stores.each(&:validate!)
    end

    def config
      @config ||= NoopBackup.config
    end

    # File name of the current backup. Example:
    #
    #  prefix   db_name            y    m  d  h  m  s  ms
    # /database/db_name_production/2026/07/03-14-47-23-724.dump
    def generate_key
      now = Time.now.utc

      [
        config.prefix,
        config.pg_env["PGDATABASE"],
        now.strftime("%Y"),
        now.strftime("%m"),
        "#{now.strftime("%d-%H-%M-%S-%L")}.dump"
      ].compact.join("/")
    end
  end
end
