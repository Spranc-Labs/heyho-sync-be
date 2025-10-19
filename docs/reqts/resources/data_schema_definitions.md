# Data Schema Definitions

This document provides the formal JSON Schema definitions for the core data models that are synchronized between the `browser-extension` and the `heyho-backend`. Using a formal schema ensures that both client and server have a strict, shared understanding of the data structures, types, and required fields.

## Overview

- **`pageVisit`**: Represents the factual record of a single page navigation.
- **`tabAggregate`**: Represents the summary of user engagement with a `pageVisit`.

Both client and backend should use these schemas to validate data before processing or transmission.

---

## `pageVisit` Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "PageVisit",
  "description": "A record of a single page navigation event.",
  "type": "object",
  "properties": {
    "id": {
      "description": "Client-generated unique identifier for the event.",
      "type": "string",
      "format": "uuid"
    },
    "url": {
      "description": "The full URL of the page visited.",
      "type": "string",
      "format": "uri"
    },
    "title": {
      "description": "The title of the page at the time of the visit.",
      "type": "string"
    },
    "visited_at": {
      "description": "The ISO 8601 timestamp of when the page visit occurred.",
      "type": "string",
      "format": "date-time"
    },
    "source_page_visit_id": {
      "description": "The ID of the pageVisit the user navigated from, if within the same tab.",
      "type": ["string", "null"],
      "format": "uuid"
    }
  },
  "required": ["id", "url", "title", "visited_at"]
}
```

---

## `tabAggregate` Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "TabAggregate",
  "description": "A summary of user engagement related to a single pageVisit.",
  "type": "object",
  "properties": {
    "id": {
      "description": "Client-generated unique identifier for the aggregate record.",
      "type": "string",
      "format": "uuid"
    },
    "page_visit_id": {
      "description": "The ID of the pageVisit this aggregate data belongs to.",
      "type": "string",
      "format": "uuid"
    },
    "total_time_seconds": {
      "description": "Total time the tab was open for this page visit, in seconds.",
      "type": "integer",
      "minimum": 0
    },
    "active_time_seconds": {
      "description": "Time the user was actively engaged with the page (not idle), in seconds.",
      "type": "integer",
      "minimum": 0
    },
    "scroll_depth_percent": {
      "description": "The maximum percentage the user scrolled down the page.",
      "type": "integer",
      "minimum": 0,
      "maximum": 100
    },
    "closed_at": {
      "description": "The ISO 8601 timestamp of when the tab was closed.",
      "type": "string",
      "format": "date-time"
    }
  },
  "required": ["id", "page_visit_id", "total_time_seconds", "active_time_seconds", "closed_at"]
}
```
