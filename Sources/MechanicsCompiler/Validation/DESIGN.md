# Transactional Compilation Validation

## Purpose and Scope
Own actual compile admission and deterministic structured diagnostics (MD-004/006 initial tree domain). Parent: [MechanicsCompiler](../DESIGN.md). No children.

## Responsibilities and Boundaries
Validate IDs/frames/references, topology, modes, physical inertia under requested policy, representations, coordinates/chart and initial assembly; invoke registered bounded extension domains; construct report/sparsity/dependencies and publish only complete immutable models. Graph compiler does not solve arbitrary constraints or loops.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Records](../CompilationRecords/DESIGN.md) | depends on | Complete descriptor/layout | Output publication | Preserve original records |
| [Capabilities](../Capabilities/DESIGN.md) | depends on | Required generic validation service | Exact feature/schema admission | Registry metadata grants descriptor validation only |
| [Model Inertia](../../MechanicsModel/Inertia/DESIGN.md) | depends on | Physical policy validation | Recheck supplied tensor under compiler policy | Loose input policy does not override compiler admission |
| [Joints Trees](../../MechanicsJoints/ArticulatedTrees/DESIGN.md) | depends on | Actual tree and motion operators | End-to-end initial chart/pose evaluation | Errors are mapped by known stage/record, without dynamic error casts |

## Architecture
```text
bounded immutable input -> canonical IDs/registration/reference/topology checks
 -> strict inertia/structural mode checks -> actual tree/layout -> initial joint/frame/body motion
 -> pose/representation/capability/extension-domain checks -> pattern/dependencies/report
 -> complete CompiledMechanicalModel
any failure -> typed CompilationFailure(deterministic diagnostics), no model
```

## Contracts and Invariants
Topology permits connected single-root trees with dedicated unique body/world/anchor frames. Cycles explicitly require unsupported closed-loop assembly; dangling endpoints, duplicate IDs and multiple parents identify implicated records. Static invariance requires no free coordinate or prescribed anchor anywhere on its ancestor path, regardless of initially zero velocity. Prescribed-kinematic body requires at least one prescribed motion source and no dynamic-state coordinate on its ancestor path. Dynamic body inertia is required and revalidated under explicit policy. Fixed chart authority must be fixed; free chart authority must be dynamicState or prescribedMotion.

Initial state matches model revision/counts and all required prescribed anchor derivative samples. Each local joint and full tree executes the actual producer evaluator; initial chart singularity, missing derivatives, arithmetic errors and inconsistent body poses are failures. Relative SI/radian pose tolerance is caller-owned. Representation requirements explicitly select required shape/display/collision slots and exact versus bounded inertia; missing data is not replaced. Compiler-wide force-law domains are handled by registered validators only; unknown schemas fail, no generic success fallback.

Compilation failures are deterministic ordered diagnostics with stage/code/implicated IDs; current implementation is fail-fast except a supplier's explicitly bounded list. Producer untyped errors are translated at the exact operation/record stage without runtime metadata casts. No partial result or invalid report is returned. Cancellation is checked at bounded phase/record boundaries.

## State, Ownership, and Lifecycle
Every mutation belongs to operation-local arrays/maps/NumericalWork. Input records and initial arrays remain unchanged. Publication occurs after all admission and output invariants pass. Immutable results can be shared by independent states; runtime owns evolution/lifetime thereafter.

## Failure, Concurrency, and Constraints
Policy bounds record count, identifier UTF-8 bytes, dense kinematic scalar budget, structural sparsity entries, dependency/cache entries, prescribed sample count, extension count/work and diagnostics before corresponding output allocation. Integer products/ranges are checked. Topology/canonicalization O(N log N), body ancestor dependencies/pattern O(B*V+B^2), actual kinematic evaluation O(B*V+B); all stored pattern entries/records are policy-bounded. Array copies occur at compile/output ownership boundaries; repeated runtime dynamics is outside this construction path.

## Verification and Change Impact
[Test owner](../../../Tests/MechanicsCompilerTests/DESIGN.md) invalid catalog proves offending ID/stage and absence of partial model; analytic tree proves rank/layout/pattern and actual motion. Mode checks include movable ancestors with zero initial velocity and moving anchors. Changes invalidate dependent runtime, exchange, CAD and physics admission assumptions.
