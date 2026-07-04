require "test_helper"

module NoopBackup
  class Commands::BackupTest < Minitest::Test
    def setup
      NoopBackup.reset!
    end

    def test_single_store_streams_full_dump
      sink = StringIO.new
      fake_store = build_store(sink:)

      text = "Look at my horse, my horse is amazing"
      configure(stores: [fake_store], command: dump_command(output: text))

      result = NoopBackup::Commands::Backup.execute

      assert result.success?
      assert_equal(text, sink.string)
    end

    def test_two_stores_stream_full_dump
      sink_a = StringIO.new
      sink_b = StringIO.new
      store_a = build_store(sink: sink_a)
      store_b = build_store(sink: sink_b)

      text = "Look at my horse, my horse is amazing"
      configure(stores: [store_a, store_b], command: dump_command(output: text))

      result = NoopBackup::Commands::Backup.execute

      assert result.success?
      assert_equal(text, sink_a.string)
      assert_equal(text, sink_b.string)
      assert_equal(2, result.store_results.size)
      assert result.store_results.all?(&:success)
    end

    def test_dump_failure_cleans_up_stores_that_already_succeeded
      sink = StringIO.new
      fake_store = build_store(sink:)

      configure(stores: [fake_store], command: dump_command(output: "truncated dump", exit_code: 1))

      result = NoopBackup::Commands::Backup.execute

      refute result.success?
      assert_instance_of NoopBackup::DumpFailedError, result.error
      assert_equal(1, fake_store.cleanup_calls.size)
    end

    private

    def build_store(sink:)
      store = NoopBackup::Stores::FakeStore.new(sink:)
      store.key = "test-123"
      store
    end

    def configure(stores:, command:)
      NoopBackup.configure do |config|
        config.pg_database = "test-123"
        config.report = false
        config.dump_command = command
        stores.each { |store| config.stores << store }
      end
    end

    def dump_command(output:, exit_code: 0)
      [
        RbConfig.ruby,
        "-e",
        "STDOUT.binmode; STDOUT.write(#{output.inspect}); exit(#{exit_code})"
      ]
    end
  end
end
