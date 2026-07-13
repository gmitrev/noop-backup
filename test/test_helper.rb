$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "boring_backup"
require_relative "support/fake_store"

require "minitest/autorun"
require "minitest/reporters"

Minitest::Reporters.use! Minitest::Reporters::DefaultReporter.new(color: true)
