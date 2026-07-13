require "test_helper"

module BoringBackup
  class ConfigurationTest < Minitest::Test
    def setup
      BoringBackup.reset!
    end

    def test_dump_command_without_ignore_tables
      config = build_config

      assert_equal(["pg_dump", "--format=custom", "--no-owner"], config.dump_command.drop(1))
    end

    def test_dump_command_appends_one_flag_per_ignored_table
      config = build_config
      config.ignore_tables = ["versions", "public.logs", "audit.*"]

      assert_equal(
        [
          "pg_dump",
          "--format=custom",
          "--no-owner",
          "--exclude-table-data=versions",
          "--exclude-table-data=public.logs",
          "--exclude-table-data=audit.*"
        ],
        config.dump_command.drop(1)
      )
    end

    def test_ignore_tables_normalizes_blanks_and_duplicates
      config = build_config
      config.ignore_tables = ["  versions  ", "", "   ", "versions", :logs]

      assert_equal(["versions", "logs"], config.ignore_tables)
    end

    def test_ignore_tables_defaults_to_empty
      config = build_config

      assert_empty(config.ignore_tables)

      config.ignore_tables = nil

      assert_empty(config.ignore_tables)
    end

    def test_ignore_tables_reads_the_env_var
      with_env("BB_IGNORE_TABLES", "versions,logs") do
        assert_equal(["versions", "logs"], build_config.ignore_tables)
      end

      with_env("BB_IGNORE_TABLES", "") do
        assert_empty(build_config.ignore_tables)
      end
    end

    def test_explicit_dump_command_ignores_ignore_tables
      config = build_config
      config.ignore_tables = ["versions"]
      config.dump_command = ["cat", "dump.sql"]

      assert_equal(["cat", "dump.sql"], config.dump_command)
    end

    private

    def build_config
      config = BoringBackup::Configuration.new
      config.pg_database = "boring_backup_test"
      config
    end

    def with_env(key, value)
      previous = ENV[key]
      ENV[key] = value
      yield
    ensure
      ENV[key] = previous
    end
  end
end
