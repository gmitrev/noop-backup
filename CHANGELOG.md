## [Unreleased]

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
