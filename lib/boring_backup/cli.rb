require "thor"
require "pastel"
require "tty-prompt"
require "tty-spinner"

module BoringBackup
  class CLI < Thor
    include Thor::Actions

    INITIALIZER = "config/initializers/boring_backup.rb"
    RECURRING = "config/recurring.yml"
    BINSTUB = "bin/bb"

    DEFAULT_SCHEDULE = "every day at 3am"
    PRODUCTION_ANCHOR = /^production:[ \t]*\r?\n/

    SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
    REDRAW_INTERVAL = 0.1

    add_runtime_options!

    def self.exit_on_failure? = true

    def self.source_root = File.expand_path("templates", __dir__)

    desc "backup", "Create and store a new backup"
    def backup
      spinner("Booting") { BoringBackup.prepare! }

      say "  #{pastel.bold("Boring Backup")}  #{pastel.dim(BoringBackup.config.pg_env["PGDATABASE"])}"

      result = stream_backup

      result.store_results.each { |store_result| say "  #{store_line(store_result)}" }
      say "\n  #{verdict(result)}\n"

      exit 1 unless result.success?
    rescue => e
      say "  #{pastel.red("✗")} #{e.message}\n"
      exit 1
    end

    desc "doctor", "Check that backups are set up correctly"
    def doctor
      spinner("Booting") { BoringBackup.prepare! }

      say "  #{pastel.bold("Boring Backup")}  #{pastel.dim("doctor · #{BoringBackup.environment}")}"

      result = spinner("Running checks") { BoringBackup::Commands::Doctor.execute }

      width = result.checks.map { |check| check.name.length }.max

      result.checks.each { |check| say "  #{check_line(check, width)}" }
      say "\n  #{doctor_verdict(result)}\n"

      exit 1 unless result.success?
    rescue => e
      say "  #{pastel.red("✗")} #{e.message}\n"
      exit 1
    end

    desc "install", "Wire up recurring backups in this app"
    def install
      say "\n  #{pastel.bold("Boring Backup")}\n\n"

      preflight

      store = configure_store
      write_initializer(store)
      install_schedule
      install_binstub

      say_next_steps
    end

    private

    def stream_backup
      BoringBackup.config.silence_stdout!

      @started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      @frame = 0

      BoringBackup::Commands::Backup.execute(progress: meter)
    ensure
      clear_line
    end

    def meter
      return unless $stdout.tty?

      ->(bytes) { draw_meter(bytes) }
    end

    def draw_meter(bytes)
      now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      return if @drawn_at && now - @drawn_at < REDRAW_INTERVAL

      @drawn_at = now
      elapsed = now - @started
      rate = elapsed.zero? ? 0 : bytes / elapsed
      tick = SPINNER[@frame = (@frame + 1) % SPINNER.size]

      $stdout.print "\r  #{pastel.cyan(tick)}  Dumping #{pastel.bold(human(bytes))} " \
        "#{pastel.dim("· #{human(rate)}/s · #{elapsed.round}s")}\e[K"
    end

    def clear_line
      $stdout.print "\r\e[K" if $stdout.tty?
    end

    def store_line(store_result)
      if store_result.success
        "#{pastel.green("✓")} #{pastel.bold(store_result.store.to_s.ljust(6))} " \
          "#{human(store_result.bytes)} in #{store_result.duration.round(1)}s  #{pastel.dim("→ /#{store_result.key}")}"
      else
        "#{pastel.red("✗")} #{pastel.bold(store_result.store.to_s.ljust(6))} #{pastel.red(store_result.error.message)}"
      end
    end

    def verdict(result)
      case result.status
      when :success then pastel.green.bold("Backed up to #{result.store_results.size} store(s).")
      when :partial_success then pastel.yellow.bold("Partial: #{result.store_results.count(&:success)}/#{result.store_results.size} stores succeeded.")
      else pastel.red.bold("Backup failed. #{result.error&.message}")
      end
    end

    def human(bytes)
      BoringBackup.utils.human_size(bytes)
    end

    CHECK_MARKS = {
      ok: ["✓", :green],
      fail: ["✗", :red],
      skip: ["–", :yellow]
    }.freeze

    def check_line(check, width)
      mark, colour = CHECK_MARKS.fetch(check.status)

      "#{pastel.decorate(mark, colour)} #{pastel.bold(check.name.to_s.ljust(width))}  #{pastel.dim(check.detail.to_s)}"
    end

    def doctor_verdict(result)
      return pastel.red.bold("#{result.failures.size} check(s) failed.") unless result.success?

      skipped = result.checks.count { |check| check.status == :skip }

      if skipped.zero?
        pastel.green.bold("Everything checks out.")
      else
        pastel.green.bold("Checks passed.") + pastel.dim(" #{skipped} skipped — run this where the credentials live to verify the bucket.")
      end
    end

    def preflight
      check "Rails app", rails? && "config/environment.rb"
      check "Scheduler", solid_queue? && "Solid Queue (#{RECURRING})", hint: "no supported scheduler found"
      check "Database", database, hint: "could not read ActiveRecord config"
      check "Store", configured_store_summary, hint: "none configured"

      say ""
    end

    def check(label, value, hint: "not found")
      mark = value ? pastel.green("✓") : pastel.yellow("✗")
      detail = value ? pastel.dim(value.to_s) : pastel.dim(hint)

      say "  #{mark} #{label.to_s.ljust(10)} #{detail}"
    end

    def rails?
      File.exist?("config/environment.rb")
    end

    def solid_queue?
      File.exist?(RECURRING) && gemfile_lock.include?("solid_queue")
    end

    def gemfile_lock
      @gemfile_lock ||= File.exist?("Gemfile.lock") ? read("Gemfile.lock") : ""
    end

    def read(path)
      File.read(path, mode: "r:UTF-8")
    end

    def database
      return @database if defined?(@database)

      @database = spinner("Reading database config") do
        BoringBackup.prepare!
        BoringBackup.config.pg_env["PGDATABASE"]
      rescue
        nil
      end
    end

    def spinner(message)
      return yield unless $stdout.tty?

      spinner = TTY::Spinner.new("  #{pastel.dim(message)} :spinner", format: :dots, clear: true, output: $stdout)
      spinner.auto_spin

      yield
    ensure
      spinner&.stop
      clear_line
    end

    def configured_store_summary
      "S3 — #{INITIALIZER}" if File.exist?(INITIALIZER)
    end

    def configure_store
      return if File.exist?(INITIALIZER)

      prompt.select("Where should backups go?") do |menu|
        menu.choice "S3 (or S3-compatible: R2, MinIO, Spaces)", :s3
      end

      {
        bucket: prompt.ask("Bucket name:", required: true),
        region: prompt.ask("Region:", default: ENV.fetch("AWS_REGION", "us-east-1"))
      }
    end

    def write_initializer(store)
      unless store
        say_status :identical, INITIALIZER, :blue
        return
      end

      create_file INITIALIZER, initializer_body(store)

      say_credentials_note
    end

    def initializer_body(store)
      <<~RUBY
        BoringBackup.configure do |config|
          config.register(:s3) do |store|
            store.bucket = #{store[:bucket].inspect}
            store.region = #{store[:region].inspect}
          end
        end
      RUBY
    end

    def say_credentials_note
      say_status :note, "credentials come from AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY in the backup environment, or an IAM role", :blue
      say "  #{pastel.dim("Keep them out of #{INITIALIZER} — it's committed.")}\n"
    end

    def install_schedule
      return print_manual_schedule unless solid_queue?

      recurring = read(RECURRING)

      if recurring.include?("BoringBackup::BackupJob")
        say_status :identical, "#{RECURRING} already runs BoringBackup::BackupJob", :blue
        return
      end

      unless recurring.match?(PRODUCTION_ANCHOR)
        say_status :skip, "#{RECURRING} has no `production:` block", :yellow
        return print_manual_schedule
      end

      schedule = prompt.ask("Schedule:", default: DEFAULT_SCHEDULE)

      return unless prompt.yes?("Add the backup job to #{RECURRING} under `production:`?")

      inject_schedule(recurring, schedule)

      say_status :insert, RECURRING, :green
      say_status :note, "backups run in production only — dev and staging are untouched", :blue
    end

    def inject_schedule(recurring, schedule)
      entry = <<~YAML.gsub(/^(?=.)/, "  ")
        boring_backup:
          class: BoringBackup::BackupJob
          schedule: #{schedule}
      YAML

      updated = recurring.sub(PRODUCTION_ANCHOR) { |anchor| "#{anchor}#{entry}" }

      File.write(RECURRING, updated, mode: "w:UTF-8")
    end

    def print_manual_schedule
      say "\n  #{pastel.yellow("No supported scheduler detected.")} Run the backup from cron instead:\n\n"
      say "#{pastel.dim("    0 3 * * *  cd /path/to/app && #{backup_command}")}\n\n"
    end

    def install_binstub
      return unless File.directory?("bin")

      if binstub?
        say_status :identical, BINSTUB, :blue
        return
      end

      return unless prompt.yes?("Add a #{BINSTUB} binstub? (drops the `bundle exec` prefix)")

      run "bundle binstubs boring-backup"
    end

    def binstub?
      File.exist?(BINSTUB)
    end

    def backup_command
      binstub? ? "#{BINSTUB} backup" : "bundle exec bb backup"
    end

    def say_next_steps
      say "\n  #{pastel.bold("Next:")} #{pastel.cyan(doctor_command)}   #{pastel.dim("# check the setup before it runs at 3am")}\n\n"
    end

    def doctor_command
      binstub? ? "#{BINSTUB} doctor" : "bundle exec bb doctor"
    end

    def prompt
      @prompt ||= TTY::Prompt.new
    end

    def pastel
      @pastel ||= Pastel.new
    end
  end
end
