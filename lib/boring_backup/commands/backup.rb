require "open3"

module BoringBackup::Commands
  CommandResult = Struct.new(:error, :store_results, keyword_init: true) do
    def success?
      status == :success
    end

    def status
      return :error if error
      return :error if store_results.empty? || store_results.none?(&:success)
      return :success if store_results.all?(&:success)

      :partial_success
    end

    def messages
      return ["❌ Fatal error: #{error.message}"] if error

      store_results.map(&:message)
    end

    def report
      BoringBackup.notify(self)
    end
  end

  class Backup
    def self.execute(report: BoringBackup.config.report?, progress: nil)
      result = new(progress: progress).execute

      result.report if report

      result
    end

    def initialize(progress: nil)
      @key = generate_key
      @progress = progress
      @store_results = []
      @sinks = []
    end

    def execute
      perform_sanity_check!

      commands = [config.dump_command]

      # Pipe pg_dump through pv only when the caller isn't counting bytes itself
      commands << ["pv", "-btra"] if @progress.nil? && config.report? && system("which", "pv", out: File::NULL, err: File::NULL)

      Open3.pipeline_r(*commands) do |last_stdout, wait_threads|
        @sinks = config.stores.map do |store|
          reader, writer = IO.pipe(binmode: true)

          thread = Thread.new do
            store.backup!(@key, reader)
          rescue => e
            # *always* return a Result, even if unexpected. Add store name for debugging.
            BoringBackup::Stores::Result.new(success: false, error: e, store: store.class.name, key: @key)
          ensure
            reader.close
          end

          BoringBackup::Tee::Sink.new(store:, writer:, thread:)
        end

        sinks_fanout = BoringBackup::Tee.new(@sinks, progress: @progress)

        begin
          IO.copy_stream(last_stdout, sinks_fanout)
        rescue => e
          raise BoringBackup::DumpFailedError, "streaming failed: #{e.message}"
        ensure
          @sinks.each(&:close)
        end

        @store_results = @sinks.map(&:collect)

        raise BoringBackup::DumpFailedError, "pipeline failed" unless wait_threads.all? { |t| t.value.success? }
      end

      CommandResult.new(store_results: @store_results)
    rescue BoringBackup::DumpFailedError => error
      # The dump stream itself failed, so uploads that finished are truncated copies of a bad stream — delete them.
      # Collect the results first: if copy_stream raised, the collection line above never ran. Sinks are already
      # closed on every DumpFailedError path, so collect can't block.
      @store_results = @sinks.map(&:collect)

      cleanup_uploaded_stores!

      CommandResult.new(error:, store_results: @store_results)
    rescue => error
      CommandResult.new(error:, store_results: @store_results)
    end

    private

    # 1. Check if any stores are registered.
    # 2. Make sure **all** stores have a valid configuration
    def perform_sanity_check!
      raise BoringBackup::ConfigurationError, "No backup stores registered" if config.stores.empty?
      raise BoringBackup::ConfigurationError, "Could not resolve PGDATABASE" if config.pg_env["PGDATABASE"].to_s.empty?

      config.stores.each(&:validate!)
    end

    def cleanup_uploaded_stores!
      @sinks.each do |sink|
        sink.store.cleanup!(@key) if sink.collect&.success
      rescue => e
        warn "⚠️ Cleanup failed for #{sink.store.class}: #{e.message}"
      end
    end

    def config
      @config ||= BoringBackup.config
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
