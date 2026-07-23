require "aws-sdk-s3"
require_relative "s3"

module BoringBackup::Stores
  class R2 < S3
    def name = :r2

    def region
      value = super

      value.to_s.empty? ? "auto" : value
    end

    def validate!
      super

      raise BoringBackup::ConfigurationError, "endpoint is not configured" if endpoint.to_s.empty?
    end
  end
end
