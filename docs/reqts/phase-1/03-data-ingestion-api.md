# Phase 1, Step 3: Data Ingestion API

**Goal:** Create the secure API endpoint for receiving and storing batches of browsing data from the browser extension.

**Depends On:** [Step 2: User Authentication](./02-user-authentication.md)

**Relevant Specs:**
*   `data_sync_technical_strategy.md`
*   `data_reconciliation_and_integrity.md`
*   `data_schema_definitions.md`

---

### Step-by-Step Implementation

1.  **Create Data Models:**
    *   Generate migrations to create the `page_visits` and `tab_aggregates` tables.
    *   The table columns should correspond exactly to the fields defined in `data_schema_definitions.md`.
    *   Ensure the `id` column is of type `uuid` and is the primary key.
    *   Add indexes to foreign keys (like `page_visit_id` on `tab_aggregates`) and frequently queried columns.
    *   Run `rails db:migrate`.

2.  **Create API Controller:**
    *   Create a new controller: `Api::V1::DataSyncController`.

3.  **Define API Route:**
    *   In `config/routes.rb`, define the route for the sync endpoint:
    ```ruby
    # config/routes.rb
    namespace :api do
      namespace :v1 do
        post 'data/sync', to: 'data_sync#create'
      end
    end
    ```

4.  **Implement Controller Action:**
    *   In `DataSyncController#create`, first ensure the request is authenticated (e.g., using a `before_action :authenticate_user!`).
    *   Parse the JSON request body, expecting `pageVisits` and `tabAggregates` arrays.

5.  **Implement Transactional & Idempotent Save Logic:**
    *   Wrap the entire data saving process in an `ActiveRecord::Base.transaction` block.
    *   For the `pageVisits` array, use `PageVisit.upsert_all(visits_params, unique_by: :id)`. The `upsert_all` command is highly efficient and handles idempotency automatically.
    *   Do the same for the `tabAggregates` array.
    *   If any part of the `upsert_all` fails, the transaction will be rolled back, ensuring atomicity.

6.  **Implement Validation and Error Handling:**
    *   Before the transaction, validate the incoming data against the JSON Schemas defined in `data_schema_definitions.md`. A gem like `json-schemer` can be used for this.
    *   If validation fails, immediately return a `400 Bad Request` with a detailed error message, as specified in `data_sync_technical_strategy.md`.
    *   Rescue from potential database errors within the controller action to prevent crashes and return a `500 Internal Server Error`.

### Acceptance Criteria

*   A `POST` request to `/api/v1/data/sync` with a valid access token and a correct data payload returns `200 OK`.
*   The data from the payload is correctly saved in the `page_visits` and `tab_aggregates` tables.
*   Sending the exact same payload again succeeds (`200 OK`) but does not create duplicate records in the database.
*   A request with a missing or invalid access token returns `401 Unauthorized`.
*   A request with malformed data (that fails schema validation) returns a `400 Bad Request` with a descriptive error body.
