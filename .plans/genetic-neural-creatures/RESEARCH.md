# Genetic Neural Subsystem Research

## External Findings

Stanley and Miikkulainen's original NEAT paper defines structural growth from a minimal network. Add-connection mutation introduces a previously absent edge. Add-node mutation splits an existing edge, gives the source-to-new-node edge weight `1`, and preserves the old edge's weight on the new-node-to-destination edge. NEAT retains a disabled original gene and historical innovation numbers because crossover needs ancestry alignment. This task excludes crossover and stable IDs, so replacing the selected edge in place plus adding one edge is sufficient and avoids unused historical data.

Source: Kenneth O. Stanley and Risto Miikkulainen, “Evolving Neural Networks through Augmenting Topologies” (2002), <https://nn.cs.utexas.edu/downloads/papers/stanley.ec02.pdf>.

The requested activation labels are not standardized as one set by NEAT. The plan therefore treats their formulas as a local public contract: `LIN=x`, `SIG=1/(1+exp(-x))`, `TANH=tanh(x)`, `SQR=x²`, `SIN=sin(x)`, `ABS=abs(x)`, `REL=max(0,x)`, and `GAU=exp(-x²)`. `LAT` is explicitly stateful and toggles between `0` and `1` only on a non-positive-to-positive input crossing. A numerically stable sigmoid branch and finite-value validation are required.

Official Odin documentation confirms that directories are packages, `main` imports child packages, tests use `@(test)` with `core:testing`, and multi-package tests require `odin test ... -all-packages`. Dynamic arrays retain allocator ownership but still require explicit deletion. `core:math/rand` accepts an explicit `rand.Generator`; the installed version can create per-owner xoshiro generators from caller-owned state. `core:thread` and its pool APIs require thread-safe or task-owned allocators.

Sources:

- Odin package and testing documentation, <https://odin-lang.org/docs/overview/> and <https://odin-lang.org/docs/testing/>.
- Installed Odin `dev-2026-07:301c287de`, especially `core:math/rand` and `core:thread`.

## Codebase Findings

The project builds with `odin build src` and currently has no tests (`odin test src -all-packages` reports “No tests to run”). `src/neural` already exists and is empty. All top-level source files are `package main`; `src/ecs` is the only leaf package.

`CreatureData` in `src/creature.odin` currently contains `BaseGenes` and unused `CreatureOutputs`. `CreatureState` defines energy and age but is not attached to entities. The only system integrates `Position` from `Velocity`; no reproduction, mutation, neural evaluation, job system, or output-consumption path exists. This supports the clarified subsystem-only boundary.

The key storage constraint is in `src/ecs/storage.odin`: components are copied and moved using raw `mem.copy`, and nested allocations are not destroyed with component rows. A `NeuralGenes` value containing owned slices or dynamic arrays would therefore leak or alias after archetype movement. Bounded inline arrays are safe and make component copying deterministic. Initial capacities of 32 hidden nodes and 128 connections cost roughly 1 to 2 KiB per creature, depending on final layout, and should be asserted/measured.

The current `SystemDefinition` procedure field demonstrates the repository's existing replaceable-implementation pattern. A neural evaluator procedure table can follow it while keeping schema, genes, runtime state, and mutation results as implementation-independent values.

## Design Implications

- Put the reusable model and interface in `package neural`; let `package main` define creature input/output enums and a `neural.Schema`. This prevents an Odin import cycle.
- Use role-local node references rather than persistent IDs. Hidden swap removal must delete incident edges and remap the moved hidden index.
- Keep all edges acyclic, including edges around latch nodes. Internal latch state is the only temporal feedback.
- Use fixed scratch arrays, explicit RNG generators, and no mutable package globals. Parallel callers give each creature distinct genes, runtime, output, and RNG storage.
- Leave movement wiring and `CreatureState` attachment for a later task. The zero-value genome is valid; constructors and tests can create direct input-to-output links explicitly.
