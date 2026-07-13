module BoringBackup::Notifiers
  class Stdout
    def notify(result)
      result.messages.each { |message| puts message }
    end
  end
end
