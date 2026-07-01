module NoopBackup
  class Configuration
    attr_accessor :bucket,
      :region,
      :prefix,
      :pg_host,
      :pg_port,
      :pg_user,
      :pg_password,
      :pg_database,
      :min_size

    def initialize
      @bucket = ENV["NBU_BUCKET"]
      @region = ENV["NBU_REGION"] || ENV["AWS_REGION"] || "auto"
      @prefix = "backups"
      @notifiers = [NoopBackup::Notifiers::Stdout.new]
      @min_size = ENV.fetch("NBU_MIN_SIZE", 1204).to_i
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
