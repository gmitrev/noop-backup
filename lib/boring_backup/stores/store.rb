module BoringBackup::Stores
  class Store
    def name
      self.class.name.split("::").last.downcase.to_sym
    end

    def description
      name
    end

    private

    def config
      @config ||= BoringBackup.config
    end
  end
end
