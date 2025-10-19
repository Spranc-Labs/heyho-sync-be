# Phase 1, Step 4: Background Job Processor

**Goal:** Integrate a background job processor (Sidekiq) to enable asynchronous processing of ingested data.

**Depends On:** [Step 3: Data Ingestion API](./03-data-ingestion-api.md)

**Relevant Specs:**
*   `roadmap.md`

---

### Step-by-Step Implementation

1.  **Add and Configure Sidekiq:**
    *   Add the `sidekiq` gem to your `Gemfile` and run `bundle install`.
    *   Follow the basic Sidekiq setup instructions. This typically involves creating a `config/initializers/sidekiq.rb` to configure the Redis connection.
    *   Ensure Redis is installed and running on your local machine.

2.  **Create Initial Background Jobs:**
    *   Generate the first set of job classes. These will be responsible for the heavy lifting of data analysis later.
    ```bash
    rails generate sidekiq:job ProcessPageVisit
    rails generate sidekiq:job ProcessTabAggregate
    ```
    *   For now, the `perform` method in these jobs can be empty or simply log the ID of the record they are supposed to process.

3.  **Enqueue Jobs After Data Ingestion:**
    *   Modify the `Api::V1::DataSyncController` from the previous step.
    *   After the database transaction successfully commits, iterate through the IDs of the newly saved `pageVisits` and `tabAggregates`.
    *   For each ID, enqueue the corresponding background job.

    ```ruby
    # In DataSyncController, after successful transaction
    saved_visit_ids.each do |visit_id|
      ProcessPageVisitJob.perform_async(visit_id)
    end
    
    saved_aggregate_ids.each do |aggregate_id|
      ProcessTabAggregateJob.perform_async(aggregate_id)
    end
    ```

4.  **Set Up Sidekiq Monitoring (Optional but Recommended):**
    *   Sidekiq comes with a web UI for monitoring jobs.
    *   Mount the UI in `config/routes.rb`, protecting it with authentication in a production environment.

### Acceptance Criteria

*   After a successful data sync to `/api/v1/data/sync`, new `ProcessPageVisitJob` and `ProcessTabAggregateJob` jobs appear in the Sidekiq queue.
*   The Sidekiq worker process can be started (`bundle exec sidekiq`) and it correctly processes the jobs from the queue without errors.
*   The Sidekiq Web UI is accessible and shows the processing status of jobs.
