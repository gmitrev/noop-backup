require "thor"

module NoopBackup
  class CLI < Thor
    def self.exit_on_failure? = true

    desc "backup", "Create and store a new backup"
    def backup
      NoopBackup.prepare!
      NoopBackup::Commands::Backup.execute
    rescue => e
      warn e
      exit 1
    end
  end
end
