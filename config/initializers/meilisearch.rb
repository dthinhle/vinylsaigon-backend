# frozen_string_literal: true

MEILISEARCH_CLIENT = Meilisearch::Client.new(
  ENV.fetch('MEILISEARCH_HOST', 'http://localhost:7700'),
  ENV.fetch('MEILISEARCH_BACKEND_KEY', ''),
  timeout:     10,
  max_retries: 3,
)

MEILISEARCH_ENABLED = MEILISEARCH_CLIENT.healthy?
