# Genetic Neural Networks

## Model And Topology

The `neural` package implements bounded sparse feed-forward networks without depending on ECS, raylib, or simulation code. Inputs and outputs are implicit fixed nodes described by a `Schema`; only hidden nodes and directed weighted connections are stored in `Genes`. Creature genomes use 32 hidden-node slots and 128 connection slots, with active counts identifying the used prefix of each fixed array.

Legal connections start at an input or hidden node and end at a hidden or output node. Self-loops, duplicate edges, edges into inputs, edges out of outputs, and cycles are invalid. A missing connection is inactive, while a present zero-weight connection remains part of the topology. The zero-value genome is valid and emits zero outputs.

Creature slots are fixed in `src/creature.odin`:

- Inputs: normalized energy, then normalized age.
- Outputs: raw speed control, then raw rotation control.

Output nodes return a finite, unactivated weighted sum. Movement-specific clamping, scaling, and rotation units are intentionally left to later behavior integration.

## Evaluation And Memory

`Default_Evaluator` returns a procedure table that evaluates a genome using fixed stack scratch arrays. Evaluation performs no heap allocation. External inputs, intermediate sums, activations, and outputs are sanitized so non-finite values become zero.

Hidden nodes support linear, sigmoid, hyperbolic tangent, square, sine, absolute, rectified linear, Gaussian, and latch activations. A latch toggles when its summed input crosses from non-positive to positive. Holding a positive signal does not toggle it again. `Runtime_State` stores latch output and edge-detection memory separately from genetic data; calling the evaluator's `reset` procedure clears both.

Genomes are read-only by evaluator contract. Callers own `Genes`, `Runtime_State`, inputs, and outputs, and must synchronize concurrent access to the same creature.

## Mutation And Determinism

Exact mutation procedures change or remove a connection, add a legal connection, split a connection through a new linear hidden node, remove a hidden node, or change a hidden activation. Capacity exhaustion and unavailable candidates return typed no-op results without partially changing the genome. Applied mutations set `runtime_reset_required`, telling the caller to reset retained latch state before the next evaluation.

`Mutate` requires an explicit caller-owned `rand.Generator`. Its stable draw order is:

1. Mutation-rate gate.
2. Weighted operation selection.
3. Uniform candidate selection.
4. Operation-specific weight or delta selection.

Candidates are enumerated in deterministic role and index order. The mutator never retries with a different operation when the selected operation has no legal candidate. Separate creatures with disjoint storage and independent seeded generators can therefore be evaluated and mutated concurrently with schedule-independent results.

## Scope

This subsystem does not currently connect neural outputs to movement or attach runtime state to ECS entities. It also excludes reproduction, crossover, innovation tracking, speciation, arbitrary recurrent edges, and topology rendering.

Key implementation files:

- `src/neural/model.odin` defines the stable bounded data contract.
- `src/neural/evaluator.odin` implements allocation-free execution.
- `src/neural/validation.odin` owns graph constraints.
- `src/neural/mutation.odin` contains exact and seeded mutation APIs.
