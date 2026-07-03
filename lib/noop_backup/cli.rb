require "thor"

module NoopBackup
  class CLI < Thor
    def self.exit_on_failure? = true

    desc "backup", "Create and store a new backup"
    def backup
      NoopBackup.prepare!
      result = NoopBackup::Commands::Backup.execute

      result.report
    rescue => e
      warn e
      exit 1
    end
  end
end
