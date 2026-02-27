# frozen_string_literal: true

module HrQuery
  # Calls the Anthropic API to translate a French natural-language query
  # into a structured filter JSON object.
  #
  # SECURITY: Never sends SQL table names or schema to the API.
  # The prompt only describes the filter contract (see PromptBuilder).
  #
  # Uses JSON prefill technique: the LLM is forced to start its response
  # with {"version":"1", which guarantees a valid, version-tagged JSON response.
  class HrQueryInterpreterService
    ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages".freeze
    MODEL             = "claude-haiku-4-5-20251001".freeze
    MAX_TOKENS        = 1024
    TIMEOUT_SECONDS   = 15
    PREFILL           = '{"version":"1",'

    Result = Data.define(:success, :filters, :error)

    def initialize(query)
      @query = query.to_s.strip
    end

    def call
      return Result.new(success: false, filters: nil, error: "Requête vide") if @query.blank?

      raw_json = fetch_from_api
      filters  = parse_and_validate(raw_json)

      Result.new(success: true, filters: filters, error: nil)
    rescue HrQueryError => e
      Result.new(success: false, filters: nil, error: e.message)
    end

    private

    def fetch_from_api
      response = connection.post do |req|
        req.headers['x-api-key']         = api_key
        req.headers['anthropic-version'] = '2023-06-01'
        req.headers['content-type']      = 'application/json'
        req.body = build_request_body.to_json
      end

      unless response.status == 200
        raise HrQueryError, "Anthropic API error #{response.status}: #{response.body.truncate(200)}"
      end

      body = JSON.parse(response.body)
      content = body.dig('content', 0, 'text').to_s

      Rails.logger.debug("[HrQuery] Raw API response content: #{content.inspect}")

      # Strip markdown code fences
      content = content.gsub(/```(?:json)?\s*/, '').strip

      # Reconstruct full JSON: prepend prefill unless the model echoed it
      full = content.start_with?('{') ? content : PREFILL + content

      # Safety: extract from first { to last } in case of any surrounding text
      first_brace = full.index('{')
      last_brace  = full.rindex('}')
      raise HrQueryError, "Réponse sans JSON détectable" unless first_brace && last_brace

      full[first_brace..last_brace]
    rescue Faraday::TimeoutError
      raise HrQueryError, "Délai d'attente dépassé (API IA temporairement indisponible)"
    rescue Faraday::ConnectionFailed => e
      raise HrQueryError, "Connexion impossible à l'API IA : #{e.message}"
    rescue JSON::ParserError
      raise HrQueryError, "Réponse invalide de l'API IA"
    end

    def build_request_body
      {
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: PromptBuilder.system_prompt,
        messages: [
          { role: "user",      content: PromptBuilder.user_message(@query) },
          { role: "assistant", content: PREFILL }
        ]
      }
    end

    def parse_and_validate(raw_json)
      Rails.logger.debug("[HrQuery] Parsing JSON: #{raw_json.inspect}")
      filters = JSON.parse(raw_json)

      unless filters.is_a?(Hash) && filters["version"] == "1"
        raise HrQueryError, "Format de réponse invalide (version manquante ou incorrecte)"
      end

      filters
    rescue JSON::ParserError => e
      Rails.logger.error("[HrQuery] JSON parse failed: #{e.message} — raw: #{raw_json.inspect}")
      raise HrQueryError, "La réponse de l'IA n'est pas un JSON valide"
    end

    def connection
      @connection ||= Faraday.new(url: ANTHROPIC_API_URL) do |f|
        f.options.timeout      = TIMEOUT_SECONDS
        f.options.open_timeout = 5
        f.request :retry, max: 2, interval: 0.5,
                          exceptions: [Faraday::TimeoutError, Faraday::ServerError]
        f.adapter Faraday.default_adapter
      end
    end

    def api_key
      @api_key ||= begin
        key = ENV["ANTHROPIC_API_KEY"].presence || Rails.application.credentials.anthropic_api_key
        raise HrQueryError, "Clé API Anthropic non configurée (ANTHROPIC_API_KEY)" if key.blank?
        key
      end
    end
  end

  class HrQueryError < StandardError; end
end
