require "net/http"
require "uri"
require "json"

module Noop::Backup::Notifiers
  class Slack
    attr_accessor :webhook_url

    def notify(text)
      uri = URI(webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, "Content-Type" => "application/json")
      request.body = {text: text}.to_json

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
