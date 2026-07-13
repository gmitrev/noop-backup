# BoringBackup

Ruby gem for backing up PostgreSQL databases with minimum effort.

This gem is very much __unstable__. Expect APIs to change a lot before v1.0.0 is released.

## Installation

If using bundler, add the gem to your `Gemfile`:

```bash
bundle add boring-backup
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install boring-backup
```

The gem requires `pg_dump` to be installed on the machine that is running it.

## Usage

### Automatic

#### Rails 8 with Solid Queue

Add the BoringBackup job to the `config/recurring.yml` file:

```yaml
production:
  # other jobs
  boring_backup:
    class: BoringBackup::BackupJob
    schedule: at 3am every day
```

The job will run on the `:default` queue on your desired schedule.
If you wish to customize the job, create a new one and make sure to invoke
`BoringBackup::Commands::Backup.execute` in the `perform` method.


#### Sidekiq, Good Job, whenever

Create a new recurring job and have it invoke `BoringBackup::Commands::Backup.execute`

### Manually

```sh
bundle exec bb backup
```

This command will dump the database and stream it to your configured destinations without writing
anything to disk. Use any scheduler or even cron to run it periodically.

## Configuration

All configuration options can be edited in the initializer:

```rb
# config/initializers/boring-backup.rb

BoringBackup.configure do |config|
  config.register(:s3) do |store|
    store.bucket = Settings.aws.bucket
    store.region = Settings.aws.region
    store.access_key_id = Settings.aws.access_key_id
    store.secret_access_key = Settings.aws.secret_access_key
  end

  config.notifier :slack do |slack|
    slack.webhook_url = 'https://hooks.slack.com/services/whatever'
  end
end
```

### Ignoring tables

To skip the rows of tables you don't need backed up, such as audit trails or job history:

```rb
BoringBackup.configure do |config|
  config.ignore_tables = %w[versions logs]
end
```

Or set `BB_IGNORE_TABLES=versions,logs`.

A restore still creates these tables empty.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/gmitrev/boring-backup.

## Wishlist

- [ ] S3-compatible backends
- [ ] file backend
- [ ] email notifier
- [ ] SMS notifier
- [ ] restore command
- [ ] test command
- [ ] encryption
- [ ] delete stale

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
