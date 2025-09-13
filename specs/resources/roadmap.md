# HeyHo Backend Development Roadmap

This document outlines the phased development of the HeyHo backend, a Rails application designed to process browsing data and generate smart insights.

## Phase 1: Foundation and API Core

**Goal:** Build the basic infrastructure of the Rails application, including the API for data ingestion and user authentication.

*   **Task 1: Project Setup**
    *   [ ] Initialize a new Rails application.
    *   [ ] Configure the database (PostgreSQL recommended).
    *   [ ] Set up version control with Git.
*   **Task 2: User Authentication**
    *   [ ] Implement user registration and login using a token-based authentication system (e.g., Devise Token Auth).
    *   [ ] Create a `User` model with fields for email, password, and API keys.
*   **Task 3: API for Data Ingestion**
    *   [ ] Create API endpoints for receiving `pageVisits` and `tabAggregates` data.
    *   [ ] Implement data validation to ensure the integrity of the incoming data.
    *   **Idempotency:** Use a unique identifier for each record (e.g., the `id` from the extension) to prevent creating duplicate records. Implement "upsert" logic to update existing records if they are received again.
*   **Task 4: Background Job Processor**
    *   [ ] Integrate Sidekiq for asynchronous processing.
    *   [ ] Create initial background jobs for processing `pageVisits` and `tabAggregates`.

## Phase 2: Data Processing and Insight Generation

**Goal:** Implement the core logic for processing the raw data and generating the first set of "smart insights."

*   **Task 1: Data Processing Pipeline**
    *   [ ] Implement the `ProcessPageVisitJob` and `ProcessTabAggregateJob` to clean, process, and store the incoming data.
    *   **Data Continuity:** Ensure that the processing jobs can handle out-of-order events and gaps in the data.
*   **Task 2: "Unread Links" Insight**
    *   [ ] Create the `Insights::IdentifyUnreadLinksService` to identify links with low engagement.
    *   [ ] Create the `RecommendedLink` model to store the recommended links.
*   **Task 3: Daily Insight Generation**
    *   [ ] Create the `GenerateDailyInsightsJob` to run once a day.
    *   [ ] This job will use the `IdentifyUnreadLinksService` to generate recommendations for each user.

## Phase 3: Advanced Insights and Scalability

**Goal:** Enhance the "Brain" of the application with more advanced insights and ensure that the system is scalable.

*   **Task 1: Topic Modeling**
    *   [ ] Implement the `Insights::TopicModelingService` to categorize the recommended links by topic.
    *   This may involve integrating a third-party API or a library for Natural Language Processing (NLP).
*   **Task 2: Personal Productivity Insights**
    *   [ ] Implement the `Insights::PersonalProductivityService` to identify patterns in user behavior.
*   **Task 3: Scalability and Performance**
    *   [ ] Optimize database queries and background jobs for performance.
    *   [ ] Implement caching strategies to reduce the load on the database.
    *   [ ] Consider scaling the background job processing infrastructure (e.g., adding more Sidekiq workers).

## Phase 4: API for Insights and Third-Party Integrations

**Goal:** Expose the generated insights through the API and allow for third-party integrations.

*   **Task 1: API for Insights**
    *   [ ] Create API endpoints for fetching the recommended links and other insights.
*   **Task 2: Third-Party API Access**
    *   [ ] Implement a system for managing API keys for third-party applications.
    *   [ ] Document the public API for third-party developers.
