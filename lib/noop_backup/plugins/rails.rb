module NoopBackup
  class Railtie < Rails::Railtie
    initializer "noop_backup.job" do |app|
      ActiveSupport.on_load(:active_job) do
        require "noop_backup/jobs/backup_job"
      end
    end
  end
end
