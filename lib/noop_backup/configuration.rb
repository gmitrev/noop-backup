module NoopBackup
  class Configuration
    attr_accessor :prefix,
      :min_size,
      :pg_host,
      :pg_port,
      :pg_user,
      :pg_password,
      :pg_database

    attr_reader :stores

    def initialize
      @prefix = ENV.fetch("NBU_PREFIX", "database")
      @stores = []
      @min_size = ENV.fetch("NBU_MIN_SIZE", 2048).to_i
      @notifiers = [NoopBackup::Notifiers::Stdout.new]
    end

    def register(store_type)
      store =
        case store_type.to_sym
        when :s3 then NoopBackup::Stores::S3.new
        else raise NoopBackup::ConfigurationError, "unknown store type: #{store_type}"
        end

      @stores << store

      raise NoopBackup::RuntimeError, "`config.register` requires a block" unless block_given?

      yield store
    end

    def notifier(type)
      case type
      when :slack
        notifier = NoopBackup::Notifiers::Slack.new

        yield notifier

        @notifiers << notifier
      else raise "Unknown notifier: #{type}"
      end
    end

    def notify(message)
      @notifiers.each do |notifier|
        notifier.notify(message)
      end
    end

    def pg_env
      {
        "PGHOST" => pg_host || db_config[:host]&.to_s || "localhost",
        "PGPORT" => pg_port || db_config[:port]&.to_s,
        "PGUSER" => pg_user || db_config[:username]&.to_s,
        "PGPASSWORD" => pg_password || db_config[:password]&.to_s,
        "PGDATABASE" => pg_database || db_config[:database].to_s
      }.compact
    end

    def db_config
      @db_config ||= defined?(::ActiveRecord) ?
        ::ActiveRecord::Base.connection_db_config.configuration_hash : {}
    end
  end
end
