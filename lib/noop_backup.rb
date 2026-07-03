require_relative "noop_backup/version"
require_relative "noop_backup/configuration"
require_relative "noop_backup/commands/backup"
require_relative "noop_backup/stores/s3"
require_relative "noop_backup/notifiers/slack"
require_relative "noop_backup/notifiers/stdout"

module NoopBackup
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    alias_method :config, :configuration

    def configure
      yield(configuration)
    end

    # Attempt to boot host app. Booting it should trigger the configuration process.
    def prepare!
      env_file = File.expand_path("config/environment.rb")

      require env_file if File.exist?(env_file)
    end
  end
end

require_relative "noop_backup/plugins/rails" if defined? Rails::Railtie
