## [Unreleased]

- **`aws-sdk-s3` is no longer a dependency of the gem.** apps using the `:s3` store must add `gem
"aws-sdk-s3"` to their own `Gemfile`.
- New `bb install` command - wires up the initializer, the Solid Queue schedule and a `bin/bb` binstub
- `bb backup` now shows a boot spinner, a live progress meter and a coloured summary
- `config.register(:s3)` no longer requires a block - the store configures itself from the environment
- `Commands::Backup.execute` accepts a `progress:` callback with the running byte count

## [0.4.0] - 2026-07-13

- **Renamed the gem from `noop-backup` to `boring-backup`.** Breaking, with no shims:
  - `NoopBackup` namespace is now `BoringBackup`
  - executable `nbu` is now `bb`
  - `require "noop_backup"` is now `require "boring_backup"`
  - env vars are prefixed `BB_` instead of `NBU_` (`BB_PREFIX`, `BB_MIN_SIZE`,
    `BB_IGNORE_TABLES`, `BB_SENTINEL_KEY`, `BB_SENTINEL_HOST`, `BB_S3_PART_SIZE`,
    `BB_S3_THREAD_COUNT`, `BB_S3_STORAGE_CLASS`)
- Configurable storage classes for s3

## [0.3.0] - 2026-07-13

- Make s3 upload stream part size and thread count configurable
- Sentinel integration
- Option to ignore tables

## [0.2.0] - 2026-07-04

- Support multiple destination stores in a single backup run
- Delete partial uploads and fail the job safely when a dump fails
- Validate configuration before running, with clearer errors
- A lot of undocumented API and configuration changes

## [0.1.3] - 2026-07-02

- Pass `access_key_id` and `secret_access_key` in config block

## [0.1.2] - 2026-07-02

- Only `exit 1` when running the CLI, not the backup service
- Automatically load BackupJob in Rails if using ActiveJob

## [0.1.1] - 2026-07-01

- Better S3 backup naming scheme - <prefix>/<database>/<YYYY>/<MM>/<dd-HHMMSS>.dump
- Fix bundler autoloading in projects

## [0.1.0] - 2026-07-01

- Initial release
- Only supports PostrgreSQL and AWS S3
