require_relative "lib/boring_backup/version"

Gem::Specification.new do |spec|
  spec.name = "boring-backup"
  spec.version = BoringBackup::VERSION
  spec.authors = ["Georgi Mitrev"]
  spec.email = ["gvmitrev@gmail.com"]

  spec.summary = "Hassle-free database backups"
  spec.description = "The simplest way to add recurring database backups to your project with minimal setup required."
  spec.homepage = "https://github.com/gmitrev/boring-backup"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gmitrev/boring-backup/tree/main"
  spec.metadata["changelog_uri"] = "https://github.com/gmitrev/boring-backup/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = ["bb"]
  spec.require_paths = ["lib"]

  spec.add_dependency "thor"
  spec.add_dependency "aws-sdk-s3", "~> 1"
end
