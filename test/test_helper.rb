$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "noop_backup"
require_relative "support/fake_store"

require "minitest/autorun"
require "minitest/pride"
