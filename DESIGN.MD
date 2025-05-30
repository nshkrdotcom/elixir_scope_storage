# Design Document: ElixirScope.Storage (elixir_scope_storage)

## 1. Purpose & Vision

**Summary:** Event storage layer (DataAccess, EventStore).

**(Greatly Expanded Purpose based on your existing knowledge of ElixirScope and CPG features):**

The `elixir_scope_storage` library serves as a cornerstone within the broader ElixirScope ecosystem. Its primary goal is to [**EXPAND HERE: elaborate on the core problem this specific library solves, its unique contributions, and how it fits into the "Execution Cinema" vision. For example, if this is elixir_scope_ast_repo, discuss its role in providing the deep structural understanding of code through AST, CFG, DFG, and CPGs. Mention its responsibility for implementing CPGMath and CPGSemantics, and how these enable advanced static analysis beyond what typical tools offer. If it's elixir_scope_correlator, explain its criticality in linking runtime chaos to static code clarity using stable AST Node IDs, enabling features like precise error pinpointing and data flow tracking across execution contexts.**]

This library will enable developers and AI assistants interacting with `TidewaveScope` to [**EXPAND HERE: list 3-5 key benefits or capabilities this library unlocks, e.g., "perform fine-grained static analysis queries," "understand complex code relationships visually," "receive AI-driven refactoring suggestions based on deep structural insights," "trace data flow across function boundaries with semantic context."**]

## 2. Key Responsibilities

This library is responsible for:

*   [**EXPAND HERE: List 3-7 detailed responsibilities. Refer to your detailed decomposition from the previous step. For example, for `elixir_scope_ast_repo`:**]
    *   Parsing Elixir source code into Abstract Syntax Trees (ASTs).
    *   Assigning unique and stable Node IDs to AST elements for cross-component correlation.
    *   Generating Control Flow Graphs (CFGs) for functions, detailing execution paths and decision points.
    *   Generating Data Flow Graphs (DFGs), potentially using Static Single Assignment (SSA) form, to track variable definitions, uses, and data propagation.
    *   Constructing comprehensive Code Property Graphs (CPGs) by unifying AST, CFG, and DFG, including inter-procedural edges.
    *   Implementing and exposing a suite of graph algorithms (`CPGMath`) applicable to CPGs (e.g., centrality, pathfinding, community detection).
    *   Implementing and exposing code-aware semantic analysis algorithms (`CPGSemantics`) that interpret graph metrics in the context of Elixir code constructs (e.g., architectural smell detection, impact analysis).
    *   Providing a robust API for querying these static analysis artifacts.
    *   Managing the storage (e.g., ETS-backed GenServer) and lifecycle of these static representations.
    *   Integrating with file watching and synchronization mechanisms to keep the static analysis data up-to-date.

## 3. Key Modules & Structure

The primary modules within this library will be:

*   `ElixirScope.Storage.DataAccess`\n

### Proposed File Tree:

```
elixir_scope_storage/
└── lib/
    └── elixir_scope/  # Or specific subdirectory like 'ast_repository'
                elixir_scope_utils;elixir_scope_config;elixir_scope_events;storage/
        └── lib/
            └── elixir_scope/
                └── storage/
                    ├── data_access.ex
                    └── event_store.ex (facade/GenServer)
```

**(Greatly Expanded - For each key module listed above, provide a 1-2 sentence description of its role. Example for `ElixirScope.ASTRepository.Enhanced.Repository` in `elixir_scope_ast_repo`):**
*   **`ElixirScope.ASTRepository.Enhanced.Repository`**: This GenServer will act as the central access point and manager for all static analysis data, including ASTs, CFGs, DFGs, CPGs, and pre-computed algorithmic results. It will handle storage (likely ETS), retrieval, and caching strategies.
*   **`ElixirScope.ASTRepository.Enhanced.CPGMath`**: This module will house the implementations of core graph algorithms (centrality, pathfinding, community detection, etc.) adapted to work with ElixirScope's CPG data structures. Its API will be used by `CPGSemantics` and potentially directly by querying tools.
*   ... (and so on for other key modules)

## 4. Public API (Conceptual)

The main public interface of this library will revolve around:

*   [**EXPAND HERE: List 3-5 key public functions or GenServer calls. Example for `elixir_scope_ast_repo`:**]
    *   `ElixirScope.Storage.Repository.get_cpg(module_name, function_name, arity)`
    *   `ElixirScope.Storage.Repository.query_static_analysis(query_spec)`
    *   `ElixirScope.Storage.CPGMath.calculate_centrality(cpg_data, node_id, type)`
    *   `ElixirScope.Storage.CPGSemantics.detect_architectural_smells(cpg_data, opts)`
    *   `ElixirScope.Storage.PatternMatcher.match_cpg_pattern(cpg_data, pattern_definition)`

## 5. Core Data Structures

This library will primarily define/utilize:

*   [**EXPAND HERE: List 2-4 central data structures. Example for `elixir_scope_ast_repo`:**]
    *   (If defined here, otherwise referenced from `elixir_scope_ast_structures`) `CPGData.t()`, `CPGNode.t()`, `CPGEdge.t()`
    *   `EnhancedModuleData.t()`, `EnhancedFunctionData.t()` (if this library owns their full definition with CPG analysis results)
    *   Internal structs for caching algorithmic results or managing query states.

## 6. Dependencies

This library will depend on the following ElixirScope libraries:

*   `ElixirScope.Storage.EventStore`\n

## 7. Role in TidewaveScope & Interactions

Within the `TidewaveScope` ecosystem, the `elixir_scope_storage` library will [**EXPAND HERE: Describe how `TidewaveScope`'s plug, MCP tools, or other ElixirScope libraries will interact with this one. Example for `elixir_scope_ast_repo`:**]

*   Be initialized and managed by the `TidewaveScope.Plug`.
*   Have its `ProjectPopulator` component triggered by `TidewaveScope` (e.g., on application start in dev, or via an MCP tool) to analyze the host project.
*   Provide static analysis data (ASTs, CPGs, algorithmic metrics) to various MCP tools exposed by `TidewaveScope.MCP.Server`. For instance, an MCP tool for "code complexity" would query this repository.
*   Offer its CPG and semantic analysis results to the `elixir_scope_ai` library for AI-driven insights and to the `elixir_scope_correlator` for linking with runtime data.
*   Be updated by the `elixir_scope_compiler` if changes to AST structure (like Node ID assignment strategy) are managed here.

## 8. Future Considerations & CPG Enhancements

This library is designed with the advanced CPG functionalities (outlined in CPG_*.md documents) in mind. Future enhancements will focus on:

*   [**EXPAND HERE: List 2-3 specific CPG-related enhancements relevant to this library. Example for `elixir_scope_ast_repo`:**]
    *   Full implementation of all algorithms specified in `CPG_MATH_API.MD` and `CPG_SEMANTICS_API.MD`.
    *   Implementing the incremental CPG update strategies from `CPG_OPTIMIZATION_STRATEGIES.MD` for efficient synchronization.
    *   Developing sophisticated query optimization within `QueryExecutor` based on CPG structure and cached algorithmic results, as per `CPG_QUERY_ENHANCEMENTS.MD`.
    *   Enhancing `PatternMatcher` to fully leverage graph-theoretic properties as described in `CPG_PATTERN_DETECTION_ADVANCED.MD`.
