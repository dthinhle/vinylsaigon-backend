# AI Coding Agent Instructions for `vinylsaigon-backend`

Purpose: Make an agent immediately productive in this Rails 8.1 ecommerce + admin platform with payment, search, promotions, and background processing.

- Never generate summary or explanation text.
- Never use emoji in your responses.
- Always format your responses as code snippets.
- Keep your responses concise and to the point.
- Make sure to implement feature in a service and call the service in the controller or model
- Keep comments minimal. Remove obvious comments
- Stimulus controllers needed to be registered in application.js

## 1. Architecture Snapshot
- Rails 8.1 full app (admin HTML + JSON API). Admin namespace under `routes.rb` (`admin/*`), public API under `api/*`.
- Data layer: ActiveRecord (PostgreSQL). Background jobs: Sidekiq (`config/sidekiq.yml`) with scheduled jobs (e.g. `CollectionGeneratorJob`, `CartExpirationJob`).
- Realtime / infra: SolidCache + SolidCable; Puma + Thruster for optimized serving in production. Image variants via ActiveStorage + `image_processing`.
- Search: Meilisearch (started via Procfile process `search: docker compose up search_engine`).

## 2. Core Domains & Flows
- Cart → Order conversion handled atomically by `OrderCreatorService` (locks cart, snapshots items, applies promotions, recalculates totals, enqueues notification job).
  Example: `OrderCreatorService.call(cart: cart, user: user, shipping_address_params: {...}, apply_promotions: true, idempotency_key: 'KEY')`.
- Payment: OnePay gateway via `OnePayService` (generates payment URL, verifies callback, installment query, transaction status query). Requires multiple env vars (see Section 6).
- Promotions & Discounts: Promotions attach to `Cart` then copied to `Order` via `promotion_usages`. Final discount math isolated in `DiscountCalculator` (`app/modules/discount_calculator.rb`). Fixed first, then percentage, capped to subtotal.
- Order numbering convention: `ORD-YYYYMMDD-<8 HEX UPPER>` generated uniquely (loop with existence check).

## 3. Service Object Pattern
- Location: `app/services`. Naming: `<feature>_service.rb` or `<action>_service.rb`.
- Common API styles:
  - `.call(**args)` (e.g. `OrderCreatorService`) returning domain object or raising custom errors.
  - Explicit class methods delegating to instance (e.g. `OnePayService.generate_payment_url(order:, ip_address:)`).
- Error handling: Domain-specific error classes inside service (`AlreadyCheckedOutError`, etc.). Prefer raising; callers rescue at controller layer.
- Use transactions and locking (`Cart.transaction` + `@cart.lock!`) for critical state transitions.

## 4. Conventions & Patterns
- Promotions: Validate all before applying; non-stackable promotion cannot coexist with others. After applying, reload order and call `recalculate_totals!` on model.
- Discount calculation: Pass full `subtotal` and collection of `promotions`; do not pre-filter amounts—module handles ordering and rounding (`ROUND_VALUE = -3`).
- Environment-specific overrides: In development, SSL verification is disabled inside OnePayService's `query_dr` method when `Rails.env.development?` to ease local debugging (never do this in production).
- Sanitization: Allowed tags/attributes extended in `config/application.rb` after initialize; avoid redefining in views.
- Autoload: Custom modules in `app/modules` (added to `autoload_paths`); lib eager loaded except ignored subdirs.

## 5. Background & Scheduling
- Sidekiq queues: `default`, `mailers`, `background` (match job `queue:` when adding new jobs).
- Scheduler entries live in `config/sidekiq.yml` under `:scheduler:`. Add new cron jobs there with `active_job: true` if using ActiveJob wrapper.
- After creating a new job file under `app/jobs`, ensure queue name matches configured queues.

## 6. Payment Integration (OnePay)
Required env vars (regular + installment):
`ONEPAY_MERCHANT_ID`, `ONEPAY_ACCESS_CODE`, `ONEPAY_SECURE_HASH_SECRET`, `ONEPAY_INSTALLMENT_MERCHANT_ID`, `ONEPAY_INSTALLMENT_ACCESS_CODE`, `ONEPAY_INSTALLMENT_SECURE_HASH_SECRET`, `ONEPAY_USER`, `ONEPAY_PASSWORD`, `ONEPAY_RETURN_URL`, `ONEPAY_GATEWAY_URL`, optional `ONEPAY_AGAIN_LINK`.
- Hashing: Only `vpc_` and `user*` params except hash fields, sorted key=value joined with `&`, HMAC SHA256 (uppercase hex).
- Installments: Adds theme/card restrictions (`vpc_theme='ita'`, `vpc_CardList='INTERCARD'`).

## 7. Auth & Security
- Admins: Devise with full web controllers (`devise_for :admins ...`).
- Users: Devise JWT (API-only; sessions/password flows via custom `api/auth` endpoints).
- For new API endpoints: place under `namespace :api`; prefer explicit collection/member blocks for non-CRUD actions.

## 8. Development Workflow
- Setup: `bundle install` + `yarn install` (Corepack enabled in Docker build, local requires Node & Yarn v4). Copy `env.example` → `.env` (if used) + ensure `config/master.key` exists for decrypting credentials.
- Run processes: `bin/dev` starts Procfile: Sidekiq (`jobs`), Tailwind watcher (`css`), JS build watch (`js`), Meilisearch container (`search`). Add new watchers by editing `Procfile.dev`.
- JS bundling: `yarn build` script uses esbuild to output to `app/assets/builds`; import modules from `app/javascript`.
- Search engine: Provided via `docker compose up search_engine` process; ensure Docker running.

## 9. Testing
- Framework: RSpec (`rspec-rails`). Factories in `spec/factories`. Use `factory_bot` + `shoulda-matchers` for model specs.
- Run: `bundle exec rspec` (add `SPEC_OPTS='--format documentation'` if needed). Clean DB: relies on `database_cleaner-active_record` (configure strategy if adding feature specs).

## 10. Deployment
- Production image via multi-stage `Dockerfile` (Ruby 3.4.1). Entrypoint runs DB prep, default CMD uses Thruster wrapping Rails server.
- Kamal supported (gem present). If adding deploy tasks, keep them in `config/deploy/` & use environment variables for secrets.

## 11. Adding Features (Examples for Agent)
- New service: Create `app/services/<name>_service.rb` with `.call` returning domain entity; wrap state mutations in transactions + log with contextual tags (`Rails.logger.info`).
- New scheduled job: Implement `app/jobs/<name>_job.rb`, set `queue:`; add cron spec to `config/sidekiq.yml` under `:schedule:`.
- New API endpoint: Update `config/routes.rb` inside `namespace :api`; keep non-CRUD actions inside `collection` / `member` blocks.

## 12. Logging & Diagnostics
- Services log with structured prefixes combining service and method name (example: OnePayService generate_payment_url); follow this pattern for new services.
- Avoid leaking secrets: redact sensitive fields before logging (see `query_dr` redacts password).

Feedback: Let me know if any domains (inventory, promotions edge cases, search indexing) need deeper coverage or if internal model callbacks should be documented.
