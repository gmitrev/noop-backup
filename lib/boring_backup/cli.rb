require "thor"

module BoringBackup
  class CLI < Thor
    def self.exit_on_failure? = true

    desc "backup", "Create and store a new backup"
    def backup
      BoringBackup.prepare!
      result = BoringBackup::Commands::Backup.execute
      exit 1 unless result.success?
    rescue => e
      warn e
      exit 1
    end
  end
end
