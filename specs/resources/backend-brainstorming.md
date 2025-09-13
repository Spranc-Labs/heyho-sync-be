# Backend Brainstorming Log

This document logs the brainstorming session for the HeyHo backend service.

## Vision and Goals

*   **Primary Goal**: To build a smart recommendation engine for past browsing activity, specifically to help with ADHD by resurfacing interesting links that were closed without being read.
*   **Use Case**: The extension will collect browsing data, and the backend will analyze it to provide smart recommendations and insights.
*   **Initial Insights**: The focus is on metrics that support the primary goal, such as identifying links that were opened but not engaged with.

## Technical Requirements

*   **Insight Generation**: Daily generation of insights is sufficient to start.
*   **Scalability**: The architecture should be flexible enough to scale from a small number of users to a larger user base.
*   **Data Ownership**: The system should be user-centric, with strong authentication and data integrity. The goal is to expose users' own data back to them in a useful way, and potentially allow other apps to sync with their data with user consent.

## Proposed Rails App Structure

*   **API Core**: A standard Rails application for handling API requests, user authentication, and data reception.
*   **Background Job Processor**: Use a framework like Sidekiq or GoodJob for asynchronous data processing and insight generation.
*   **Data Analysis Engine (The "Brain")**: A set of services or modules dedicated to analyzing the data and generating insights.
