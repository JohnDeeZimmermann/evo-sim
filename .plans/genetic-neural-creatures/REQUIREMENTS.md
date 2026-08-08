# Genetic Neural Networks for Creatures

## Goal and Scope

Add a genetic neural-network subsystem whose topology and parameters can evolve through mutation. `CreatureData` will own `NeuralGenes`, while the evaluator and mutation implementation will live under `src/neural`. Genetic data, fixed creature input/output descriptions, mutable runtime state, and execution logic must remain cleanly separated so the neural implementation can be replaced later.

The first delivery is the neural subsystem, its creature-facing data integration, and tests. It does not wire neural outputs into the current movement or reproduction systems. A reusable mutation API will make later reproduction integration possible.

## Functional Requirements

### Genetic representation

- Add `NeuralGenes` to the creature genetic data in `src/creature.odin`.
- Represent a sparse set of weighted directed connections. Missing connections are inactive, so fixed input and output nodes only influence behavior when a weight links them through a valid path.
- Inputs and outputs are fixed by the creature contract rather than genetically added or removed.
- The fixed input contract is exactly normalized energy and normalized age. Callers supply both values directly; attaching or updating `CreatureState` is outside this subsystem-only scope.
- The fixed output contract is the existing speed percentage and rotation scalar. Research must define the evaluator's normalized scalar output and the adapter/clamping boundary without wiring it into movement.
- Hidden nodes are genetic and carry one of these functions: `LIN`, `SIG`, `TANH`, `SQR`, `SIN`, `ABS`, `REL`, `GAU`, or `LAT`.
- Use the local activation contract `x`, logistic sigmoid, `tanh(x)`, `x*x`, `sin(x)`, `abs(x)`, `max(0,x)`, `exp(-x*x)`, and threshold-toggle latch, respectively. Output nodes use an unactivated weighted sum; creature-domain adapters clamp or scale that value later.
- Do not add NEAT innovation tracking, crossover, or stable node/connection IDs in this task. If index-based references are used, mutation must repair or remap them safely after removals.

### Evaluation semantics

- Support feed-forward graphs only, except for explicit `LAT` nodes that retain state across evaluations.
- A `LAT` node is a threshold-triggered binary toggle. A transition of its weighted input from `<= 0` to `> 0` toggles retained state; reset starts low and returns `0`, while the high state returns `1`. Holding a positive input does not toggle repeatedly.
- Reject or avoid arbitrary recurrent connections and cycles during topology mutation and validation.
- Keep immutable genetic data separate from per-creature runtime state, especially latch memory and evaluator scratch storage.
- Define deterministic activation semantics, output ranges, input normalization, latch update timing, and behavior for disconnected nodes.
- Expose a small evaluator interface that consumes the fixed input data plus `NeuralGenes` and writes fixed outputs. Callers must not depend on the evaluator's internal graph representation or scheduling strategy.

### Mutation behavior

Provide reusable, independently testable operations for:

1. Changing an existing connection weight.
2. Removing an existing connection.
3. Adding a legal connection between two nodes.
4. Splitting an existing connection into a hidden node. The original strength moves to the hidden-to-destination connection, while a new source-to-hidden connection has weight `1`.
5. Removing a hidden node and every incident connection.
6. Changing a hidden node's activation function, including changing to or from `LAT`.

Mutation selection is driven by the creature's existing `mutation_rate` and `mutation_intensity`, through a reusable orchestration API rather than a reproduction system. An operation with no legal candidate returns an explicit no-op result. It must not loop indefinitely, silently damage the graph, or automatically substitute another mutation kind.

### Parallelism and determinism

- Evaluation and mutation must be independent per creature and safe to run concurrently for different creatures.
- Avoid shared mutable globals, global innovation counters, hidden allocator state, and shared random-number generators.
- Accept caller-owned RNG state for mutation so seeded runs are reproducible and parallel scheduling does not change an individual mutation's result.
- Make runtime memory creature-owned or caller-owned. Clearly define whether evaluation may allocate and provide a path for reusing scratch storage.
- Mutating or evaluating the same creature concurrently is outside the required safety guarantee and should be documented as requiring caller synchronization.

## Architecture Constraints

- Put neural execution, validation, activation functions, and mutation procedures in `src/neural` as an independently importable Odin package.
- Define stable, implementation-independent neural model and interface types in separate files within `src/neural`. `src/creature.odin` imports that leaf package, aliases or embeds its gene model, and owns the creature-specific input/output enums and schema. The neural package must not import `package main`.
- Keep `NeuralGenes` serializable/plain genetic data without evaluator caches or runtime latch values.
- Use bounded inline arrays plus active counts, initially 32 hidden nodes and 128 connections per genome. This avoids nested dynamic-array ownership inside byte-copied ECS components. Capacity exhaustion yields a typed no-op mutation result, and capacities remain named constants that can be tuned after measuring component size.
- Prevent the neural package from depending on ECS or simulation-loop details.
- Follow the local ECS APIs and deferred-change rules if component integration requires ECS changes.

## Verification and Acceptance Criteria

- Unit tests cover every mutation operation, legal-edge constraints, cycle prevention, no-candidate no-ops, index repair after removal, and seeded determinism.
- Evaluator tests cover all nine activation functions, sparse/disconnected graphs, multiple hidden layers, latch behavior over several ticks, and reset behavior.
- Structural validation detects invalid endpoints, illegal direction, duplicate edges if disallowed, and cycles outside latch semantics.
- Parallel tests evaluate and mutate separate creature instances concurrently without shared-state races or cross-creature contamination, subject to Odin tooling support.
- Existing project build and tests continue to pass.

## Exclusions

- Wiring outputs into movement or other creature behavior.
- Reproduction, crossover, speciation, fitness scoring, and population evolution.
- Global NEAT innovation numbers or historical markings.
- Arbitrary recurrent networks beyond explicit latch nodes.
- Rendering or editing neural topologies.

## Resolved Design Policies

- Refer to nodes by a role (`Input`, `Hidden`, or `Output`) and role-local index. Removing a hidden node uses swap removal, deletes all incident connections, and remaps references to the hidden node moved into the vacated index.
- Reject duplicate directed edges. Connections may originate at inputs or hidden nodes and terminate at hidden or output nodes. Output-to-anything and anything-to-input edges are invalid.
- Adding a connection is legal only if no path already exists from the candidate destination back to its source. `LAT` memory does not permit graph cycles.
- Keep evaluator scratch in bounded caller/local storage, so normal evaluation performs no heap allocation. Retained latch data is caller-owned runtime state and is reset after genetic mutation unless a future explicit remapping policy is added.
- Pass `rand.Generator` explicitly with no default. An orchestration call uses `mutation_rate` as the probability of attempting one weighted mutation kind and `mutation_intensity` as the weight-perturbation scale.
