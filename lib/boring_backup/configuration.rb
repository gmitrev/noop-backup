module BoringBackup
  class Configuration
    DEFAULT_SENTINEL_HOST = "https://boringbackup.com"

    attr_accessor :prefix,
      :min_size,
      :pg_host,
      :pg_port,
      :pg_user,
      :pg_password,
      :pg_database,
      :sentinel_key

    attr_reader :stores
    attr_writer :report, :dump_command, :ignore_tables, :sentinel_host

    def initialize
      @prefix = ENV.fetch("BB_PREFIX", "database")
      @stores = []
      @min_size = ENV.fetch("BB_MIN_SIZE", 2048).to_i
      @notifiers = [BoringBackup::Notifiers::Stdout.new]
      @report = true
      @ignore_tables = ENV.fetch("BB_IGNORE_TABLES", "").split(",")
      @sentinel_key = ENV["BB_SENTINEL_KEY"]
      @sentinel_host = ENV.fetch("BB_SENTINEL_HOST", DEFAULT_SENTINEL_HOST)
    end

    def report?
      @report
    end

    def sentinel_host
      @sentinel_host || DEFAULT_SENTINEL_HOST
    end

    def sentinel?
      !sentinel_key.to_s.empty?
    end

    def sentinel
      return unless sentinel?

      @sentinel ||= BoringBackup::Notifiers::Sentinel.new(key: sentinel_key, host: sentinel_host)
    end

    def notifiers
      [*@notifiers, sentinel].compact
    end

    def ignore_tables
      Array(@ignore_tables).map { |table| table.to_s.strip }.reject(&:empty?).uniq
    end

    def dump_command
      @dump_command || [
        pg_env,
        "pg_dump",
        "--format=custom",
        "--no-owner",
        *ignore_tables.map { |table| "--exclude-table-data=#{table}" }
      ]
    end

    def register(store_type)
      raise BoringBackup::ConfigurationError, "`config.register` requires a block" unless block_given?

      store =
        case store_type.to_sym
        when :s3 then BoringBackup::Stores::S3.new
        else raise BoringBackup::ConfigurationError, "unknown store type: #{store_type}"
        end

      @stores << store

      yield store
    end

    def notifier(type)
      case type
      when :slack
        notifier = BoringBackup::Notifiers::Slack.new

        yield notifier

        @notifiers << notifier
      else raise "Unknown notifier: #{type}"
      end
    end

    def pg_env
      {
        "PGHOST" => (pg_host || db_config[:host])&.to_s,
        "PGPORT" => (pg_port || db_config[:port])&.to_s,
        "PGUSER" => (pg_user || db_config[:username])&.to_s,
        "PGPASSWORD" => (pg_password || db_config[:password])&.to_s,
        "PGDATABASE" => (pg_database || db_config[:database])&.to_s
      }.compact
    end

    def db_config
      @db_config ||= defined?(::ActiveRecord) ?
        ::ActiveRecord::Base.connection_db_config.configuration_hash : {}
    end
  end
end
