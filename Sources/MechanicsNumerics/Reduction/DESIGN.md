# Reduced linear equations

## Purpose and Scope

Parent: [MechanicsNumerics](../DESIGN.md). Owns generic IM03 Schur-complement and scalar tree elimination operations for SO-002. Actual mechanical articulated-body equations remain IM15-owned; this generic algebra proves no mechanical ABA or mechanism-level O(n) claim.

## Responsibilities and Boundaries

Owns block equation elimination and recovery and a validated scalar symmetric tree system. Caller owns constraint signs, coordinate ordering, graph construction and physical interpretation. No hidden regularization or backend change.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Linear algebra](../LinearAlgebra/DESIGN.md) | depends on | dense factor/solve, shared work/acceptance | numerical supplier | failed reduced solve is a failure |
| [MechanicsNumerics](../DESIGN.md) | parent | ownership | composition | mechanics qualification remains downstream |

## Architecture

```mermaid
flowchart LR
  Blocks[A*x + B*y = f; C*x + D*y = g] --> Schur[S = D - C*A^-1*B]
  Schur --> Recover[x = A^-1*(f-B*y)]
  Tree[Parent indices and symmetric edge coefficients] --> Leaves[Leaf-to-root elimination]
  Leaves --> Back[Root-to-leaf recovery]
```

## Contracts and Invariants

Schur outputs use the input block order: first x coordinates, then y coordinates; S*y = g-C*A^-1*f. A and S are solved by caller-selected dense LU, with final residual checked in both original block equations. Tree records have one root at index 0, parent[i] < i, one scalar unknown per node, diagonal[i] and symmetric off-diagonal edge[i] between i and parent[i]. Root parent is -1 and root edge is zero. Every graph must satisfy these conditions; input cannot encode loops. Reverse-index elimination updates the parent pivot and RHS, then ascending recovery uses the same original edge coefficients. Zero/threshold pivots fail with their node index; a general nonsingular tree needing pivoting is outside this no-pivot elimination domain. Original sparse tree residual is independently computed. Array lengths, scalar storage and work counts are checked before allocation. The implementation does no dense tree assembly and reports scalar linear work counts; no physics complexity inference is made.

## State, Ownership, and Lifecycle

Immutable Sendable value records own COW arrays. Every solve owns its mutable workspace and returns owned arrays; no shared mutable caches, global state, unsafe pointers, or platform-dependent isolation are used. Matrix input ownership lasts through the synchronous operation. Cancellation is checked at bounded iteration/factorization safe points.

## Failure, Concurrency, and Constraints

Invalid dimensions, nonfinite inputs/results, numerical rank loss, nonpositive curvature/pivots, unsupported capability, cancellation and exhausted caller budgets are typed failures. No fallback changes precision, backend or algorithm. Checked products precede allocation; conservative simultaneous scalar workspace and arithmetic work are charged before use. The caller chooses resource limits and tolerances. Independent calls share no mutable state.

## Verification and Change Impact

[Test owner](../../../Tests/MechanicsNumericsTests) compares nontrivial tree branches and Schur coordinates to independent dense assembly, checks original equations, invalid parent graphs and singular reduced pivots. Downstream mechanical SO-002 equivalence requires IM15/IM48 proof. Changed coordinate/recovery semantics invalidate constraint and dynamics consumers.
