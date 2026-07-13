require "net/http"
require "uri"
require "json"

module BoringBackup::Notifiers
  class Sentinel
    PAYLOAD_VERSION = 1

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10
    MAX_ATTEMPTS = 3

    LOCAL_HOSTS = %w[localhost 127.0.0.1 0.0.0.0]

    attr_accessor :key, :host

    def initialize(key:, host:)
      @key = key
      @host = host
    end

    def ping_url
      URI.join(normalized_host, "/ping/#{key}")
    end

    def notify(result)
      body = payload(result).to_json
      attempt = 0

      begin
        attempt += 1
        response = post(body)

        return true if response.is_a?(Net::HTTPSuccess)
        raise BoringBackup::Error, "#{response.code} #{response.body}" if retryable?(response)

        warn "Sentinel ping failed: #{response.code} #{response.body}"

        false
      rescue => e
        if attempt < MAX_ATTEMPTS
          sleep(2**(attempt - 1))
          retry
        end

        warn "Sentinel ping error after #{attempt} attempts: #{e.message}"

        false
      end
    end

    private

    def normalized_host
      uri = URI.parse(host)

      return host if uri.is_a?(URI::HTTP)

      "#{LOCAL_HOSTS.include?(uri.scheme) ? "http" : "https"}://#{host}"
    end

    def post(body)
      uri = ping_url

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
      request.body = body

      http.request(request)
    end

    def retryable?(response)
      response.is_a?(Net::HTTPServerError) || response.is_a?(Net::HTTPTooManyRequests)
    end

    def payload(result)
      store_results = result.store_results

      {
        version: PAYLOAD_VERSION,
        status: result.status,
        error: result.error&.message,
        database: BoringBackup.config.pg_env["PGDATABASE"],
        bytes: store_results.filter_map(&:bytes).max,
        duration: store_results.filter_map(&:duration).max&.round(3),
        stores: store_results.map do |store_result|
          {
            store: store_result.store,
            success: store_result.success,
            key: store_result.key,
            bytes: store_result.bytes,
            duration: store_result.duration&.round(3),
            error: store_result.error&.message
          }
        end
      }
    end
  end
end
