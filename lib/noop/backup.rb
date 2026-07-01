require_relative "backup/version"
require_relative "backup/configuration"
require_relative "backup/commands/backup"
require_relative "backup/notifiers/slack"
require_relative "backup/notifiers/stdout"

module Noop::Backup
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    alias_method :config, :configuration

    def configure
      yield(configuration)
    end

    # Attempt to boot host app. Booting it should trigger the configuration process
    def prepare!
      env_file = File.expand_path("config/environment.rb")

      require env_file if File.exist?(env_file)
    end
  end
end
