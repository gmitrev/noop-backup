require "net/http"
require "uri"
require "json"

module BoringBackup::Notifiers
  class Slack
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    attr_accessor :webhook_url

    def notify(result)
      uri = URI(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.body = {text: result.messages.join("\n")}.to_json

      response = http.request(request)

      success = response.is_a?(Net::HTTPSuccess)

      warn "Slack notify failed: #{response.code} #{response.body}" unless success

      success
    rescue => e
      # Never fail a backup because of a notification error
      warn "Slack notify error: #{e.message}"
    end
  end
end
