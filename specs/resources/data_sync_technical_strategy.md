# Data Sync Technical Strategy

This document outlines the technical strategy for synchronizing browsing data from the `browser-extension` to the `heyho-backend`. The primary goal is to create a process that is robust, scalable, and efficient, capable of handling both real-time data flow and large backlogs from offline usage.

## Core Principles

Our synchronization strategy is built on these core principles:

1.  **Fixed-Size Batching:** The client will always group data into fixed-size batches to ensure reliable, consistently-sized network requests.
2.  **Chronological Batch Creation:** Batches will be created from the oldest available records in the local buffer, ensuring a logical First-In, First-Out (FIFO) processing order.
3.  **Backend Transactional Integrity:** The backend will process each batch within a single database transaction to guarantee atomicity and prevent partial data saves.
4.  **Client-Side Sync Loop:** The client will repeatedly send batches in a loop until its local data buffer is cleared.

## Ensuring True Atomicity: Backend Transactions

While sending a batch in a single API call is efficient, true atomicity is the responsibility of the backend.

**The Rule:** The backend must wrap the processing of an entire incoming batch in a **single database transaction**.

*   **On Success:** If all records in the batch are valid and successfully saved, the transaction is committed. The backend returns a `200 OK` response.
*   **On Failure:** If any record in the batch fails validation for any reason, the entire transaction is **rolled back**. No data from the batch is saved. The backend should return a `400 Bad Request` response with a body detailing the failure. This is crucial for client-side debugging.

    **Example Error Response:**
    ```json
    {
      "error": "Validation failed for one or more records",
      "failed_records": [
        {
          "id": "uuid-of-bad-record",
          "error": "Invalid URL format for pageVisit."
        }
      ]
    }
    ```

This all-or-nothing approach prevents data corruption and allows the client to identify and potentially quarantine bad data.

## Batch Size Determination

The size of each batch is determined by balancing network efficiency with the practical limits of web requests and network reliability.

*   **Primary Constraint (Payload Size):** Web servers and API gateways have request body size limits, often ranging from 1-10 MB. To ensure reliability, we will target a conservative maximum payload size of **~512 KB**.
*   **Estimated Event Size:** A single JSON event object (`pageVisit` or `tabAggregate`) is estimated to be between 1 KB and 2 KB.
*   **Usage Scenario:** The strategy is designed for the most demanding case: a "power user" coming online after being offline for several days, resulting in a backlog of thousands of events.

**Recommended Batch Size:**
A batch will consist of up to **100 `pageVisits`** and **100 `tabAggregates`**. This keeps the total number of events per request at 200, which is well within our safety margin.

## Client-Side Sync Loop Logic

The client (`browser-extension`) is responsible for managing the sync process. The logic is as follows:

1.  **Trigger Sync:** The process is initiated by a periodic timer (e.g., every 5 minutes) or when the user first logs in.

2.  **Query Local Buffer:** The extension queries its local storage for a batch of the **oldest** unsynced data:
    *   Up to 100 of the oldest `pageVisits`.
    *   Up to 100 of the oldest `tabAggregates`.

3.  **Check for Data:** If the query from the previous step returns no data, the sync process is complete and stops.

4.  **Send Batch:** If data was found, the extension sends it to the backend in a single API call.
    ```http
    POST /api/v1/data/sync
    Content-Type: application/json
    Authorization: Bearer <access_token>

    {
      "pageVisits": [ ... ],
      "tabAggregates": [ ... ]
    }
    ```

5.  **Handle Response:** The client must strictly follow this logic to ensure data integrity.
    *   **On Success (200 OK):** A `200 OK` response is the definitive confirmation that the backend has successfully saved the entire batch. The extension **must delete** the specific records that were just sent from its local buffer. This is critical to prevent duplicate sends and to manage local storage space. After deletion, the client **immediately returns to Step 2** to process the next batch, if any data remains.
    *   **On Failure (e.g., network error, 4xx/5xx server error):** Any response other than a `200 OK` means the backend has not confirmed the save. The extension **must not delete** the data from its local buffer. This ensures that the data is kept safe and can be retried on the next scheduled sync interval, preventing data loss.

This loop ensures that even a very large backlog is cleared in a series of manageable, reliable chunks, providing a robust and scalable data synchronization mechanism.
