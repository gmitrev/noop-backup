module BoringBackup
  class BackupJob < ActiveJob::Base
    queue_as :default

    def perform
      result = BoringBackup::Commands::Backup.execute

      raise BoringBackup::BackupFailedError.new(result) unless result.success?
    end
  end
end
