# Phase 1, Step 1: Project Setup

**Goal:** Initialize a new Rails 7+ application for the `heyho-backend`, configure it for a PostgreSQL database, and set up basic testing infrastructure.

---

### Step-by-Step Implementation

1.  **Initialize Rails Application:**
    *   From the project root, generate a new Rails API-only application.

    ```bash
    rails new heyho-backend --api --database=postgresql
    ```

2.  **Configure Database:**
    *   Navigate into the new `heyho-backend` directory.
    *   Open `config/database.yml`.
    *   Verify that the `default` adapter is `postgresql` and update the `username` and `password` fields if necessary for your local Postgres setup.

3.  **Create the Database:**
    *   Run the Rails command to create the development and test databases.

    ```bash
    rails db:create
    ```

4.  **Set Up Testing Framework (RSpec):**
    *   Add `rspec-rails` to the `:development, :test` group in the `Gemfile`.

    ```ruby
    # Gemfile
    group :development, :test do
      gem "rspec-rails", "~> 6.0.0"
    end
    ```
    *   Install the gem and run the RSpec installer.

    ```bash
    bundle install
    rails generate rspec:install
    ```

5.  **Initialize Version Control:**
    *   Ensure a `.gitignore` file exists and is properly configured for a Rails application.
    *   Initialize a new Git repository.

    ```bash
    git init
    git add .
    git commit -m "Initial commit: New Rails application for heyho-backend"
    ```

### Acceptance Criteria

*   The Rails server can be started successfully (`rails s`).
*   The command `rails db:version` runs without errors.
*   The command `bundle exec rspec` runs without errors and reports 0 examples.
