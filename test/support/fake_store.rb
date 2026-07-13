module BoringBackup::Stores
  class FakeStore < Store
    attr_accessor :key
    attr_reader :sink, :cleanup_calls

    def initialize(sink: StringIO.new)
      @sink = sink
      @cleanup_calls = []
    end

    def backup!(key, stream)
      bytes = IO.copy_stream(stream, sink)
      Result.new(success: true, store: :fake, bytes:, key:, duration: 100)
    end

    def validate!
      raise BoringBackup::ConfigurationError, "key is not configured" unless key
    end

    def cleanup!(key)
      @cleanup_calls << key
    end
  end
end
