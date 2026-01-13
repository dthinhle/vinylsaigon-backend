# frozen_string_literal: true

module Api
  class QueryController < Api::BaseController
    def perform
      headers['Authorization'] = "Bearer #{ENV.fetch('MEILISEARCH_BACKEND_KEY')}"
      response = HTTParty.send(
        request.method.downcase.to_sym,
        request.path.gsub(%r{.*/query}, MEILISEARCH_HOST),
        body:    query_params.to_json,
        headers: {
          authorization:  "Bearer #{ENV.fetch('MEILISEARCH_BACKEND_KEY')}",
          'content-type': 'application/json'
        },
      )
      if response.code >= 400
        message = response.parsed_response && response.parsed_response['message'] ? response.parsed_response['message'] : 'Failed to query'
        Rails.logger.error("[MeiliSearch][Error] #{message}")
        return render json: {
          success: false,
          message:
        }
      end

      render json: response.parsed_response
    end

    private

    def query_params
      @query_params ||= begin
        query = request.params['query']
        return query if Rails.env.production?

        if query.respond_to?(:[]) && query['queries'].is_a?(Array)
          query['queries'].each do |subquery|
            subquery['showRankingScore'] = true
          end
        end

        query
      end
    end
  end
end
