# Design Document: ElixirScope.Storage (elixir_scope_storage)

## 1. Purpose & Vision

**Summary:** Provides a high-performance, ETS-based storage layer for ElixirScope events, featuring multiple indexes for efficient querying across various dimensions (temporal, process, function, correlation).

**(Greatly Expanded Purpose based on your existing knowledge of ElixirScope and CPG features):**

The `elixir_scope_storage` library is the primary persistence and querying backend for runtime events captured by ElixirScope. Its core mission is to efficiently store potentially vast numbers of `ElixirScope.Events.t()` structs and allow for their rapid retrieval based on diverse query criteria. This stored event data is fundamental for both real-time analysis and post-hoc debugging, including the "Execution Cinema" capabilities.

This library aims to:
*   **Provide Scalable Event Storage:** Utilize ETS tables, designed for high concurrency and in-memory speed, to store millions of events.
*   **Implement Multi-Dimensional Indexing:** Maintain several indexes (temporal, process ID, function signature, correlation ID, and critically, `ast_node_id`) to optimize query performance across common access patterns.
*   **Ensure Fast Writes:** Optimize event storage operations (`store_event`, `store_events_batch`) for high throughput, accommodating bursts of events from the capture pipeline.
*   **Support Efficient Queries:** Offer a query API that can leverage the indexes to quickly retrieve specific subsets of events (e.g., events within a time range, events for a particular process, events linked to a specific AST node).
*   **Manage Data Lifecycle:** Include mechanisms for data pruning (e.g., based on age or total event count) to keep memory usage bounded, especially for "hot" storage.
*   **Abstract Storage Details:** Provide a clean API (`ElixirScope.Storage.EventStore`) that hides the underlying ETS implementation details from consumers.
*   **Integrate with CPG Correlation:** The `ast_node_id` index is a key feature, allowing efficient retrieval of all runtime events associated with a specific CPG node, enabling powerful CPG-centric debugging and analysis.

The data stored and indexed by this library, particularly events tagged with `ast_node_id`, is crucial for the `elixir_scope_correlator` to establish links between runtime behavior and static code structures (CPGs). It also directly serves queries from `TidewaveScope` MCP tools that need access to historical event data.

This library will enable:
*   The `elixir_scope_capture_pipeline` to durably (in-memory) store processed events.
*   The `elixir_scope_correlator` and `elixir_scope_temporal_debug` to efficiently query events needed for their analyses.
*   `TidewaveScope` (via MCP tools) to retrieve and display event logs based on various filters.
*   Efficient lookup of runtime events when a user or AI navigates code via its CPG representation and wants to see associated dynamic behavior.

## 2. Key Responsibilities

This library is responsible for:

*   **Event Storage (`DataAccess` & `EventStore`):**
    *   Creating and managing ETS tables for primary event data and various indexes.
    *   Providing functions to store single events and batches of events.
    *   Ensuring data integrity and handling potential ETS limits or errors.
*   **Indexing:**
    *   Maintaining a temporal index (e.g., `timestamp -> event_id`) for time-range queries.
    *   Maintaining a process index (e.g., `pid -> [event_id]`).
    *   Maintaining a function index (e.g., `{module, function, arity} -> [event_id]`).
    *   Maintaining a correlation ID index (e.g., `correlation_id -> [event_id]`).
    *   **Crucially, maintaining an `ast_node_id` index (e.g., `ast_node_id -> [event_id]`) for CPG integration.**
*   **Querying:**
    *   Providing an API to query events based on time ranges, PIDs, function signatures, correlation IDs, `ast_node_id`s, and combinations thereof.
    *   Optimizing queries to use the most appropriate index.
*   **Data Management:**
    *   Implementing strategies for event pruning (e.g., based on maximum event count or event age) to manage memory usage.
    *   Providing functions to clear storage or specific portions of it.
*   **Statistics:**
    *   Tracking statistics about stored events, index sizes, and memory usage.

## 3. Key Modules & Structure

The primary modules within this library will be:

*   `ElixirScope.Storage.DataAccess` (Low-level ETS table management and core storage/query logic)
*   `ElixirScope.Storage.EventStore` (GenServer providing a public API and managing the `DataAccess` instance lifecycle)
*   `ElixirScope.Storage.QueryOptimizer` (Internal module to help `DataAccess` choose the best index for a query)
*   `ElixirScope.Storage.Pruner` (Internal module or logic for automatic data cleanup)

### Proposed File Tree:

```
elixir_scope_storage/
├── lib/
│   └── elixir_scope/
│       └── storage/
│           ├── event_store.ex    # GenServer API
│           ├── data_access.ex    # ETS logic
│           ├── query_optimizer.ex # Internal
│           └── pruner.ex         # Internal
├── mix.exs
├── README.md
├── DESIGN.MD
└── test/
    ├── test_helper.exs
    └── elixir_scope/
        └── storage/
            ├── event_store_test.exs
            └── data_access_test.exs
```

**(Greatly Expanded - Module Description):**
*   **`ElixirScope.Storage.EventStore` (GenServer):** This module will be the main public API for interacting with the event storage system. It will manage the lifecycle of the `DataAccess` component (which handles the ETS tables). It will forward requests like `store_event`, `query_events` to `DataAccess` and manage any overarching concerns like periodic pruning calls or statistics aggregation.
*   **`ElixirScope.Storage.DataAccess`**: This module encapsulates all direct interactions with the ETS tables.
    *   It will be responsible for creating the primary events table (`event_id -> event_struct`) and all index tables (`timestamp -> event_id`, `pid -> event_id`, `mfa -> event_id`, `correlation_id -> event_id`, `ast_node_id -> event_id`).
    *   It implements the logic for inserting events into the primary table and updating all relevant indexes atomically or consistently.
    *   It contains the core query logic that uses the indexes to retrieve sets of `event_id`s, which are then used to look up full events from the primary table.
    *   It will handle data pruning from all tables when triggered.
*   **`ElixirScope.Storage.QueryOptimizer` (Internal):** This module, used by `DataAccess`, will analyze a given query filter set and determine the most efficient index(es) to use. For example, if a query has both a `pid` and a `timestamp_since`, it might decide whether to first filter by PID then by time, or vice-versa, based on estimated selectivity or index statistics.
*   **`ElixirScope.Storage.Pruner` (Internal):** This module will contain the logic for deleting old events to stay within configured limits (e.g., max number of events, max age of events). It will need to carefully remove entries from the primary table and all associated index tables.

## 4. Public API (Conceptual)

The main public interface will be through `ElixirScope.Storage.EventStore`:

*   `ElixirScope.Storage.EventStore.start_link(opts :: keyword()) :: GenServer.on_start()`
    *   Options: `:name` (for GenServer), `:max_events`, `:cleanup_interval_ms`.
*   `ElixirScope.Storage.EventStore.store_event(store_ref :: pid() | atom(), event :: ElixirScope.Events.t()) :: :ok | {:error, term()}`
*   `ElixirScope.Storage.EventStore.store_events(store_ref :: pid() | atom(), events :: [ElixirScope.Events.t()]) :: {:ok, count_stored :: non_neg_integer()} | {:error, term()}`
*   `ElixirScope.Storage.EventStore.query_events(store_ref :: pid() | atom(), filters :: keyword() | map()) :: {:ok, [ElixirScope.Events.t()]} | {:error, term()}`
    *   Filters can include: `:pid`, `:event_type`, `:since_timestamp`, `:until_timestamp`, `:correlation_id`, `:ast_node_id`, `:module`, `:function`, `:arity`, `:limit`, `:order (:asc | :desc)`.
*   `ElixirScope.Storage.EventStore.get_event_by_id(store_ref :: pid() | atom(), event_id :: String.t()) :: {:ok, ElixirScope.Events.t()} | {:error, :not_found}`
*   `ElixirScope.Storage.EventStore.get_stats(store_ref :: pid() | atom()) :: {:ok, map()}`
    *   Returns stats like total events, memory usage, index sizes, oldest/newest event timestamps.
*   `ElixirScope.Storage.EventStore.cleanup_old_events(store_ref :: pid() | atom(), cutoff_criteria :: term()) :: {:ok, count_removed :: non_neg_integer()} | {:error, term()}`
    *   `cutoff_criteria` could be a timestamp or a maximum age.
*   `ElixirScope.Storage.EventStore.get_instrumentation_plan(store_ref :: pid() | atom()) :: {:ok, map()} | {:error, :not_found}` (If plans are stored here as per original `DataAccess`)
*   `ElixirScope.Storage.EventStore.store_instrumentation_plan(store_ref :: pid() | atom(), plan :: map()) :: :ok | {:error, term()}` (If plans are stored here)

## 5. Core Data Structures

*   **ETS Table Schemas:**
    *   `primary_table` (`event_id :: String.t()` => `event_struct :: ElixirScope.Events.t()`) - Type: `set`
    *   `temporal_index` (`timestamp :: integer()` => `event_id :: String.t()`) - Type: `ordered_set` (key is timestamp for range queries)
    *   `process_index` (`pid :: pid()` => `event_id :: String.t()`) - Type: `bag`
    *   `function_index` (`{module(), atom(), non_neg_integer()}` => `event_id :: String.t()`) - Type: `bag`
    *   `correlation_index` (`correlation_id :: term()` => `event_id :: String.t()`) - Type: `bag`
    *   `ast_node_index` (`ast_node_id :: String.t()` => `event_id :: String.t()`) - Type: `bag`
    *   `stats_table` (`stat_key :: atom()` => `value :: any()`) - Type: `set`
*   Consumes: `ElixirScope.Events.t()` (from `elixir_scope_events`)

## 6. Dependencies

This library will depend on the following ElixirScope libraries:

*   `elixir_scope_utils` (for `generate_id`, timestamps, etc.)
*   `elixir_scope_config` (for `max_events`, `cleanup_interval`, etc.)
*   `elixir_scope_events` (defines the event structs being stored)

It will depend on Elixir core libraries (`:ets`, `GenServer`).

## 7. Role in TidewaveScope & Interactions

Within the `TidewaveScope` ecosystem, the `elixir_scope_storage` library will:

*   Be started and managed by the main `TidewaveScope` application (or `elixir_scope_capture_pipeline` if that becomes the higher-level manager).
*   Receive events to store from the `elixir_scope_capture_pipeline` (specifically, its `AsyncWriter`s).
*   Serve query requests from:
    *   `elixir_scope_correlator` (e.g., to find related events by correlation ID or `ast_node_id`).
    *   `elixir_scope_temporal_debug` (for time-range queries, `ast_node_id` queries for state reconstruction).
    *   `elixir_scope_ai` (if AI models need to query historical event patterns).
    *   `TidewaveScope` MCP tools (e.g., a tool to "show last 100 events for PID X" or "show events for function Y").
*   The `CPG_ETS_INTEGRATION.md` from your CPG docs is relevant here if CPG-specific data or events are stored, though it seems more focused on the `elixir_scope_ast_repo`'s internal storage. This library focuses on *runtime* event storage that can be *linked* to the CPG via `ast_node_id`.

## 8. Future Considerations & CPG Enhancements

*   **Warm/Cold Storage Tiers:** Extend beyond "hot" ETS storage to persist events to disk (warm storage, e.g., Dets or RocksDB via a NIF) or an external database/object store (cold storage) for long-term retention, as hinted in your original `ElixirScope.Config`.
*   **Advanced Query Language:** Develop a more expressive internal query language that the `QueryOptimizer` can parse and translate into efficient ETS operations.
*   **Index Optimization:** Dynamically monitor query patterns and suggest or automatically create/drop indexes.
*   **Distributed Queries:** If `TidewaveScope` runs in a distributed Elixir environment, this library might need to coordinate queries across multiple storage instances (likely handled by a higher-level coordinator that uses this library on each node).
*   **CPG-Aware Query Optimizations:** If CPG data is accessible, the `QueryOptimizer` could potentially use CPG structure to infer selectivity of `ast_node_id` filters. For example, if an `ast_node_id` corresponds to a rarely executed part of a CPG, a query filtering by it is highly selective.

## 9. Testing Strategy

*   **`ElixirScope.Storage.DataAccess` Unit Tests:**
    *   Test ETS table creation and basic insert/lookup/delete operations for the primary table and each index.
    *   Test correct updating of all indexes upon event insertion.
    *   Test correct removal from all indexes upon event deletion (during pruning).
    *   Test query logic for each index type (temporal range, PID lookup, MFA lookup, correlation ID, `ast_node_id`).
    *   Test pruning logic: ensure it removes the correct events and updates stats.
    *   Test concurrency: multiple processes writing and reading simultaneously (stress testing).
*   **`ElixirScope.Storage.EventStore` GenServer Tests:**
    *   Test `start_link` and basic API calls (`store_event`, `query_events`, `get_stats`).
    *   Test correct delegation to `DataAccess`.
    *   Test periodic cleanup if managed by `EventStore`.
*   **`ElixirScope.Storage.QueryOptimizer` Unit Tests (if it becomes a distinct module):**
    *   Test its ability to choose the correct index for various query filter combinations.
*   **Performance Benchmarks:**
    *   Benchmark `store_event` and `store_events` throughput.
    *   Benchmark query latency for different filter types and data volumes.
