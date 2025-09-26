# Data Granularity Strategy: Processed Abstractions vs. Raw Events

This document outlines the strategic decision to sync pre-processed data models from the `browser-extension` to the `heyho-backend`, rather than the lowest-level raw browser events.

## The Core Decision

The `heyho-backend` will ingest and store two primary, pre-processed data models:

1.  `pageVisits`
2.  `tabAggregates`

We will **not** capture or store the underlying raw events used to create these models (e.g., individual scroll events, mouse movements, tab focus changes, etc.).

## Rationale

This is a conscious architectural trade-off. We are prioritizing efficiency, simplicity, and cost-effectiveness over maximum data granularity, as the chosen abstractions provide sufficient value for the product's core goals.

### 1. The Power of Good Abstractions

The `pageVisits` and `tabAggregates` models are high-quality abstractions that are specifically designed to answer the key questions the product is built on (e.g., "Was this page read?").

*   `pageVisits` provides the factual record of **what** was visited.
*   `tabAggregates` provides the contextual summary of **how** it was engaged with.

By having the client perform this initial layer of processing, we are efficiently extracting the signal from the noise at the source.

### 2. The Prohibitive Cost of Raw Events

Attempting to capture and store all raw browser events would introduce significant challenges with diminishing returns for our current objectives:

*   **Massive Data Volume:** A raw event stream would be orders of magnitude larger than syncing the processed models. This would dramatically increase storage costs, database load, and network traffic.
*   **Increased Backend Complexity:** The backend's job would become vastly more complex. It would need to ingest a chaotic stream of events and perform the computationally expensive task of "sessionizing" them—stitching them together to figure out what actually happened. Our current model offloads this lightweight task to the client.
*   **Diminishing Returns:** For the primary goal of identifying unread links, the raw events provide very little value beyond what is already captured in the `tabAggregates` model.

### 3. A Pragmatic Design Choice

This strategy represents an 80/20 approach. The `pageVisits` and `tabAggregates` models provide the vast majority of the value needed for the product roadmap, while avoiding the immense cost and complexity of a full raw event ingestion pipeline.

This pragmatic choice allows for faster development, a more performant system, and a more manageable cost structure.

## Future Considerations

This decision is not irreversible. If a future product feature is conceived that requires more granular event data, we can make a targeted decision to introduce a new data model at that time. For the foreseeable future, however, the current strategy is the most effective path forward.
