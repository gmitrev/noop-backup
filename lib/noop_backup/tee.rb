module NoopBackup
  class Tee
    Sink = Struct.new(:writer, :thread, keyword_init: true) do
      attr_reader :error

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

      def join
        thread.join
      end
    end

    def initialize(sinks) = @sinks = sinks

    def write(chunk)
      @sinks.each { |sink| sink.write(chunk) }

      chunk.bytesize
    end
  end
end
