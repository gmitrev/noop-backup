module NoopBackup::Stores
  class FakeStore < Store
    attr_accessor :key
    attr_reader :sink

    def initialize(sink: StringIO.new)
      @sink = sink
    end

    def backup!(key, stream)
      bytes = IO.copy_stream(stream, sink)
      Result.new(success: true, store: :fake, bytes:, key:, duration: 100)
    end

    def validate!
      raise NoopBackup::ConfigurationError, "key is not configured" unless key
    end

    def cleanup!(key)
    end
  end
end
