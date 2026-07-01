require "test_helper"

class TestNoopBackup < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::NoopBackup::VERSION
  end
end
