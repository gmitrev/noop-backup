module BoringBackup
  class Railtie < Rails::Railtie
    initializer "boring_backup.job" do |app|
      ActiveSupport.on_load(:active_job) do
        require "boring_backup/jobs/backup_job"
      end
    end
  end
end
