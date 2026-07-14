module BoringBackup
  class Tee
    Sink = Struct.new(:store, :writer, :thread, keyword_init: true) do
      def write(chunk)
        return if @error

        writer.write(chunk)
      rescue Errno::EPIPE, IOError => e
        @error = e

        close unless writer.closed?
      end

      def close
        writer.close
      end

      def collect
        thread.value
      rescue
        nil
      end
    end

    attr_reader :bytes

    def initialize(sinks, progress: nil)
      @sinks = sinks
      @progress = progress
      @bytes = 0
    end

    def write(chunk)
      @sinks.each { |sink| sink.write(chunk) }

      @bytes += chunk.bytesize
      @progress&.call(@bytes)

      chunk.bytesize
    end
  end
end
