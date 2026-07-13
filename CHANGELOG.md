## [Unreleased]

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
