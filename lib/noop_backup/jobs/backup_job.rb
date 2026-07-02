module NoopBackup
  class BackupJob < ActiveJob::Base
    queue_as :backups

    def perform
      NoopBackup::Commands::Backup.execute
    end
  end
end
