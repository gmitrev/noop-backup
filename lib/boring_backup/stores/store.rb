module BoringBackup::Stores
  class Store
    private

    def config
      @config ||= BoringBackup.config
    end
  end
end
