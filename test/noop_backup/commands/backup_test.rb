require "test_helper"

module NoopBackup
  class Commands::BackupTest < Minitest::Test
    def setup
      # TODO
      # NoopBackup.reset!
    end

    def test_single_store_streams_full_dump
      sink = StringIO.new
      fake_store = NoopBackup::Stores::FakeStore.new(sink:)
      fake_store.key = "test-123"

      NoopBackup.configure do |config|
        config.pg_database = "test-123"
        config.stores << fake_store
      end

      text = "Look at my horse, my horse is amazing"
      command = generate_shell_command(output: text)

      # TODO: Find a way to disable the report implicitly, maybe a flag when running tests
      # or only output when in terminal, not in scripts
      result = NoopBackup::Commands::Backup.execute(command:, report: false)

      assert result.success?
      assert_equal(sink.string, text)
    end

    private

    def generate_shell_command(output:, exit_code: 0)
      [
        RbConfig.ruby,
        "-e",
        "STDOUT.binmode; STDOUT.write(#{output.inspect}); exit(#{exit_code})"
      ]
    end
  end
end
