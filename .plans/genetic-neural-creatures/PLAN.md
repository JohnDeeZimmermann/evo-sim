# Genetic Neural Networks Implementation Plan

## Objective

Introduce a bounded, sparse genetic neural-network model for creatures, plus activation, validation, evaluation, and mutation APIs in `src/neural`. The first version exposes fixed creature inputs (normalized energy and age) and fixed outputs (speed and rotation slots), but does not run the network from the game loop, alter movement, or implement reproduction.

The design is inspired by NEAT's topology-growing mutations while intentionally excluding crossover, innovation numbers, speciation, and arbitrary recurrent edges. Explicit latch nodes provide the only memory. Every genome, runtime state, scratch value, and random generator is creature-owned or caller-owned, so independent creatures can be processed in parallel without shared mutable state.

## Architectural Shape

### Package boundary

`src/neural` becomes a leaf package with no dependency on `package main`, ECS, raylib, or simulation systems. Separate source files in that package distinguish the stable data/API contract from the default implementation:

- `src/neural/model.odin`: schema, genes, node references, activation enum, runtime state, limits, and result types.
- `src/neural/interface.odin`: evaluator procedure signatures and a constructor for the default implementation table.
- `src/neural/activation.odin`: pure activation and finite-value helpers.
- `src/neural/validation.odin`: structural validation and graph predicates.
- `src/neural/evaluator.odin`: the default allocation-free feed-forward evaluator.
- `src/neural/mutation.odin`: exact mutation primitives, random candidate selection, and mutation orchestration.

`src/creature.odin` imports `neural`, aliases its plain gene type as `NeuralGenes`, embeds it in `CreatureData`, and defines the creature-specific slot enums and schema. This dependency direction avoids an Odin package cycle and lets another evaluator satisfy the same procedure contract without changing genetic data.

### Storage and capacity

Use only scalar fields and fixed arrays in `NeuralGenes`. The local ECS moves component rows with raw byte copies and has no nested-value destructor, so slices, dynamic arrays, maps, strings, pointers, or allocator ownership must never enter this type.

Start with these named limits:

- `MAX_HIDDEN_NODES = 32`
- `MAX_CONNECTIONS = 128`

Each array has an active count. Capacity exhaustion is a normal typed no-op, not a panic. Add compile-time size assertions, with an initial target of at most 2 KiB for `NeuralGenes` and 4 KiB for `CreatureData`, and add a test or type-info guard that catches reference-bearing fields if practical with the installed Odin version.

### Stable model and illustrative API

Use role-local indices instead of stable or historical IDs:

```odin
Node_Role :: enum u8 {Input, Hidden, Output}
Node_Ref  :: struct {role: Node_Role, index: u8}

Activation :: enum u8 {LIN, SIG, TANH, SQR, SIN, ABS, REL, GAU, LAT}

Hidden_Node_Gene :: struct {activation: Activation}
Connection_Gene  :: struct {source, destination: Node_Ref, weight: f32}

Schema :: struct {input_count, output_count: u8}
Genes  :: struct {
    hidden_count:     u8,
    hidden_nodes:     [MAX_HIDDEN_NODES]Hidden_Node_Gene,
    connection_count: u16,
    connections:      [MAX_CONNECTIONS]Connection_Gene,
}

Runtime_State :: struct {
    latch_on:           [MAX_HIDDEN_NODES]bool,
    latch_was_positive: [MAX_HIDDEN_NODES]bool,
}
```

Exact Odin names can follow repository formatting, but preserve these roles and ownership rules. Fixed input and output nodes are implicit in `Schema`; they are not copied into each genome. Connection presence means enabled. Removing a connection physically removes it, and a zero-weight connection remains present but contributes zero.

Expose an evaluator procedure contract similar to the existing `SystemDefinition.run` seam:

```odin
Evaluate_Proc :: #type proc(
    schema: Schema,
    genes: ^Genes,             // read-only by contract
    state: ^Runtime_State,
    inputs: []f32,
    outputs: []f32,
) -> Evaluation_Status

Evaluator :: struct {
    evaluate: Evaluate_Proc,
    reset:    Reset_Proc,
}
```

Return the default table by value from a procedure rather than storing mutable package-global state. `inputs` and `outputs` must exactly match `Schema` counts. All implementations share the observable latch/reset contract, but callers do not see topological-order or accumulation internals.

## Numeric and Graph Semantics

### Creature contract

In `src/creature.odin`, define enums whose ordinal values pin the fixed slots:

- Input `0`: normalized energy in `[0, 1]`.
- Input `1`: normalized age in `[0, 1]`.
- Output `0`: raw speed control.
- Output `1`: raw rotation control.

Define `CREATURE_NEURAL_SCHEMA` with two inputs and two outputs, plus packing helpers that accept normalized/percentage values and produce the positional input array. Keep output values as finite raw neural controls in this task. Converting speed to `Percentage` and defining rotation units belongs to later behavior integration, because current `CreatureOutputs.rotate` has no documented absolute/delta or degree/radian contract.

The zero-value genome is valid and produces zero raw outputs. Initialize the new `CreatureData.neural_genes` field explicitly to the zero value in `create_creatures` for clarity. Do not attach `CreatureState` or add a neural system yet.

### Activation functions

Apply each hidden function to the sum of all incoming weighted values:

| Label | Function |
|---|---|
| `LIN` | `x` |
| `SIG` | `1 / (1 + exp(-x))`, using an overflow-safe positive/negative branch |
| `TANH` | `tanh(x)` |
| `SQR` | `x * x` |
| `SIN` | `sin(x)` |
| `ABS` | `abs(x)` |
| `REL` | `max(0, x)` |
| `GAU` | `exp(-(x * x))` |
| `LAT` | retained binary toggle described below |

Sanitize non-finite external inputs to zero. Mutation and validation keep weights finite and within a configurable default range of `[-8, 8]`. After every accumulation and activation, convert a non-finite result to zero so malformed input or overflow cannot poison later ticks. Output nodes have no activation function; they return their sanitized weighted sum.

A disconnected hidden node evaluates `activation(0)`. This deliberately means `SIG` emits `0.5` and `GAU` emits `1`; those values only matter if an outgoing connection exists.

### Latch behavior

`LAT` uses the same weighted input sum as every other hidden node. Its state starts low, with `latch_was_positive = false`.

1. Sanitize the current summed input.
2. Compute `is_positive = sum > 0`.
3. If `is_positive` and the prior value was not positive, toggle `latch_on`.
4. Store `is_positive` for edge detection.
5. Return `1` when on, otherwise `0`.

Thus a positive first tick toggles on, a held-positive input does not toggle repeatedly, and another toggle requires a non-positive tick followed by a positive tick. Reset clears both arrays, so a positive input immediately after reset toggles once. A disconnected latch remains low.

Any applied genetic mutation returns `runtime_reset_required = true`. The mutator does not receive or modify runtime state; the caller resets it before the altered genome is next evaluated. No-op mutations preserve state. This coarse policy is intentional for the first version and avoids hidden-index remapping of live memory.

### Legal graphs

Connections may be:

- input to hidden or output;
- hidden to hidden or output.

Reject edges into inputs, edges out of outputs, self-loops, duplicates, and any candidate whose destination can already reach its source. Latch nodes do not exempt an edge from acyclicity. Add-node splitting preserves acyclicity; all other mutation kinds except add-connection either remove edges or leave endpoints unchanged.

Validation checks active counts, endpoint roles and ranges, finite/bounded weights, duplicate edges, and cycles. It is a constructor/load/test defensive API, not a full pass called from every evaluation. The evaluator still performs cheap count and endpoint guards before indexing, and its topological pass reports a cycle rather than hanging.

## Detailed Implementation Steps

### 1. Establish the plain neural model

Create `src/neural/model.odin` with all constants, enums, fixed-capacity structs, and typed status values. Keep errors/results expressive enough for tests and callers:

- Validation errors: invalid schema/count, invalid endpoint, illegal direction, duplicate edge, non-finite/out-of-range weight, and cycle.
- Evaluation statuses: success, invalid dimensions, invalid genome, and cycle.
- Mutation kind: change weight, remove weight, add weight, split weight, remove hidden, and change function.
- Mutation status: applied, skipped by rate, no candidate, hidden capacity, connection capacity, invalid argument, and invalid genome.
- Mutation result fields: status, attempted kind, and `runtime_reset_required`.

Add zero-value and size invariants. `Schema{2,2}`, `Genes{}`, and `Runtime_State{}` must all be usable without allocation or cleanup.

### 2. Add the creature-facing schema and genes

Modify `src/creature.odin` without discarding the user's existing uncommitted `Percentage`, `CreatureOutputs`, or `CreatureState` work.

- Import `neural`.
- Define `NeuralGenes :: neural.Genes` so the creature layer exposes the requested domain name while the reusable package owns its layout.
- Add `neural_genes: NeuralGenes` beside `base_genes` in `CreatureData`; keep outputs as runtime data rather than placing them inside genes.
- Add fixed input/output slot enums, the two-by-two schema, and a small input-packing helper.
- Explicitly zero-initialize `neural_genes` in creature creation. Do not initialize random edges or alter velocity, movement, rendering, or the game loop.

Add a root-package test confirming enum ordinals, schema counts, input packing/clamping, the valid zero genome, and the component-size budget.

### 3. Implement activation and sanitization helpers

Create `src/neural/activation.odin` with one dispatch procedure over `Activation`. Keep non-latch functions pure. Implement sigmoid with separate positive and negative branches to avoid exponent overflow, and sanitize before and after activation.

Keep latch mutation in the evaluator or a helper that takes explicit `^Runtime_State` and hidden index. Do not use static locals or package-global arrays.

Write table-driven tests for all nine functions at representative negative, zero, and positive values. Include large finite values, NaN, positive infinity, and negative infinity; every returned value must be finite. Test exact special points such as `SIG(0)=0.5`, `TANH(0)=0`, `REL(-1)=0`, and `GAU(0)=1` with tolerances for transcendental functions.

### 4. Build validation and graph helpers

Create `src/neural/validation.odin` with:

- `validate(schema, genes) -> Validation_Error` or an equivalent typed result;
- endpoint and direction predicates;
- edge-existence lookup;
- bounded reachability used to test whether adding `source -> destination` creates a cycle;
- an optional topological-order helper using fixed arrays.

Use deterministic role/index iteration. With at most 32 hidden nodes and 128 connections, straightforward bounded scans are preferable to allocation-heavy adjacency structures. Treat `source == destination` as a cycle of length zero. Never recurse without a bounded visited set.

Test every invalid category directly. Also construct valid multi-layer, disconnected, and latch-containing DAGs. Validation must not modify genes.

### 5. Implement the default evaluator

Create `src/neural/evaluator.odin`. Use stack-local fixed arrays for hidden sums, hidden outputs, indegrees, and the Kahn queue. Evaluation performs no heap allocation.

Evaluation order:

1. Check slice lengths and active counts before indexing.
2. Clear active scratch slots and caller output slots.
3. For every input-source edge, accumulate into its hidden or output destination.
4. Build hidden-to-hidden indegrees and enqueue all zero-indegree hidden nodes in ascending index order.
5. Pop each hidden node, activate its accumulated sum (including latch state updates), and propagate its value through outgoing edges.
6. Decrement destination indegrees and enqueue newly ready hidden nodes deterministically.
7. Report a cycle if fewer than `hidden_count` nodes were processed.
8. Sanitize and write output sums in fixed slot order.

Do not mutate genes. A given `(schema, genes, prior runtime, inputs)` must produce the same outputs and next runtime independent of which worker executes it.

Evaluator tests cover direct input-to-output weights, several hidden layers, fan-in/fan-out, connection ordering, disconnected activations, all latch transitions over multiple ticks, reset, invalid dimensions/endpoints, cycles, extreme numeric values, and unchanged genes after evaluation.

### 6. Implement exact mutation primitives

First implement deterministic primitives that take explicit connection indices, hidden indices, endpoints, weights, or activation values. They enable focused tests without relying on RNG.

- **Change weight:** add a supplied delta and clamp to configured bounds.
- **Remove weight:** stable-remove the selected connection and clear the now-inactive tail slot.
- **Add weight:** preflight capacity, direction, endpoint range, duplicate status, and cycle status before appending.
- **Split weight:** atomically verify one free hidden slot and one free net connection slot. Add a `LIN` hidden node, rewrite the selected old connection as `new_hidden -> old_destination` with its original weight, then append `old_source -> new_hidden` with weight `1`. If either capacity is unavailable, change nothing.
- **Remove hidden:** stable-compact all connections not incident to the selected node. If the removed hidden is not last, move the last hidden gene into the gap and remap surviving references from the old last index to the gap. Decrement the count and clear inactive tails.
- **Change function:** reject an invalid hidden index and otherwise replace its activation; the random wrapper must choose a function different from the current one.

Run validation after each primitive in tests. Add before/after byte comparisons for every no-op path to prove atomicity. Specifically test split at each capacity boundary and hidden removal with incoming, outgoing, moved-node, and unrelated connections.

### 7. Add seeded mutation selection

Define `Mutation_Config` separately from genes. Include six operation-selection weights, added-weight range (default `[-1,1]`), and allowed weight range (default `[-8,8]`). Use equal operation weights initially so policy is explicit and easy to revise.

The public `mutate` procedure takes `rand.Generator` as a required argument with no default, plus `mutation_rate` and `mutation_intensity` from `BaseGenes`:

1. Clamp rate to `[0,1]` and intensity to non-negative.
2. Draw once for a Bernoulli gate. A failed gate returns `Skipped_Rate`.
3. Draw once from the configured operation weights.
4. Enumerate that kind's legal candidates in deterministic role/index or array order.
5. Select uniformly from legal candidates. If none exist, return `No_Candidate`; never retry a different kind.
6. For weight change, draw an additive uniform delta in `[-intensity,+intensity]` and clamp the result.
7. For add-weight, draw uniformly from the configured added-weight range.
8. Apply the exact primitive and return its typed result.

Use a two-pass legal-candidate count/select strategy or bounded reservoir method that allocates nothing. Prefer two-pass selection because it consumes one candidate-selection draw regardless of candidate count. Document the RNG draw order so a fixed seed is reproducible within this implementation.

Mutation tests include fixed-seed golden results, rate zero/one behavior, each forced operation kind, no-candidate behavior, no silent substitution, bounds, uniform candidate reachability over many seeds without statistical flakiness, and preservation of graph validity after long mutation sequences.

### 8. Prove independent-creature parallel safety

Add a test that prepares multiple independent genomes, runtime states, output arrays, xoshiro states, and `rand.Generator` values. Run the same evaluation/mutation workload serially and through `core:thread` workers, ensuring each worker receives disjoint storage. Compare resulting genes, runtime states, mutation results, and outputs byte-for-byte.

Workers must not call `testing` assertions concurrently; they write result records, and the main test thread asserts after joining. The neural package must not allocate in this workload, touch ECS/world state, or use `context.random_generator`. Document that concurrent access to the same creature still requires caller synchronization.

This test establishes schedule-independent results for per-creature seeds. It does not introduce a production job scheduler, parallelize ECS queries, or solve potential false sharing between adjacent ECS rows.

### 9. Document and verify the contract

Add concise package documentation, either comments in `src/neural/model.odin` plus `docs/neural.md`, covering:

- fixed versus genetic nodes;
- activation and latch semantics;
- ownership/reset rules;
- legal topology and capacity no-ops;
- explicit RNG and parallel-safety contract;
- exclusions such as crossover and behavior wiring.

Ensure the root test command discovers `package neural` tests. If needed, add `src/tests.odin` with `@require import "neural"` following Odin's multi-package test convention.

Run, in order:

1. Odin formatter on only the added/modified Odin files.
2. `odin test src/neural` for focused package tests.
3. `odin test src -all-packages` for the complete suite.
4. `odin build src -out:/tmp/opencode/evo-sim-neural` for the application build.

The baseline already builds, and the baseline all-package test command reports no tests. Treat any new failure or warning as introduced by this work.

## Completion Criteria

- Every creature carries plain, bounded `NeuralGenes` containing hidden functions and sparse weighted connections.
- Fixed energy/age and speed/rotation slot data is visible in the creature layer, while `package neural` remains independent of ECS and simulation types.
- The default evaluator is swappable through a documented procedure contract and allocates no heap memory per call.
- All nine hidden functions and exact latch/reset behavior are implemented and numerically finite at API boundaries.
- All six requested mutations are atomic, deterministic under an explicit seed, preserve valid acyclic topology, and report typed no-ops.
- Serial and parallel independent-creature workloads produce byte-identical results with per-creature seeds.
- No movement, reproduction, rendering, or game-loop behavior is changed.
- Focused tests, all-package tests, and the application build pass.
