# NeighborContacts

## Purpose and Scope
Exhaustive neighbors and contact history transport. Initial admitted implementation domain; behavioral/profile qualification pending. Parent [module](../DESIGN.md); no children.

## Responsibilities and Boundaries
Own complete finite binding graph queries, neighbor capacity, common force port, actual compliant-law evaluation and tangent transport. Dependencies are public CollisionGeometryQuerying and ContactLawEvaluating requirements. ContactResponse implicit normal response and Hybrid isolated impacts were traced but are not used as a substitute for frictional DEM.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | SI vectors/rotations | Explicit typed failures |
| [Collision](../../Collision/DESIGN.md) | depends on | analytic framed witnesses | No box/mesh/approximate geometry admission |
| [ContactLaws](../../ContactLaws/DESIGN.md) | depends on | material pairs, history and force | Spring friction is not exact Coulomb |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | NumericalWork | Separate supplier units |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | depends on | RuntimeRandomState | No session/wire checkpoint claim |
| [Tests](../../../../../Tests/MechanicsGranularTests/DESIGN.md) | used by | physical/failure oracles | Execution is root-owned |

## Architecture
```text
identified immutable model/state -> bounded owned operation -> immutable contribution or typed failure
```

## Contracts and Invariants
Each binding is queried every step, including open contacts; old friction energy is released through the actual evaluator. Neighbor means separation <= reversible cohesion range (zero if none). All persistent histories survive checkpoint. Real sphere/sphere and sphere/half-space witness inputs are generated from current centers. Degenerate coincident centers fail. Common application point=(pointA+pointB)/2 co-locates equal/opposite forces and preserves pair angular momentum; it is a declared compliant port approximation, not a surface traction field.

## Runtime Flows
Basis is initially deterministic and subsequently transported by shortest rotation from previous normal to current normal; bristle coordinates stay unchanged, preserving their energy. Normal changes below caller minimumTransportDot are unsupported; initial antipodal +Z to -Z chooses declared +X half-turn. Law trial uses old velocities and dt; bristle friction is the actual regularized spring law, not maximum-dissipation Coulomb. Cohesion is reversible, not fracture. Supplier work is separate mutable inout CollisionWork/ContactWork and invocation count; failures preserve actual ledgers and stop once. Gates enforce unchanged published budget and nondecreasing counters/storage; violation restores known pre-call work and returns failedSupplierWorkUnavailable=true (including invalidSupplierLedger). These gates cannot certify unreported internal arithmetic or same-budget resetting from an initial zero ledger; supplying providers must satisfy their published actual-work contract. Provider metadata inputs are immutable; malformed supplier force/history/geometry evidence is rejected before publication. An independent bristle potential and tangential work identity is recomputed from original input, accepted and trial histories; force decomposition/global power are also checked independently. Supplier responsibility still owns the actual normal constitutive curve.

## State, Ownership, and Lifecycle
Inputs/results are immutable Sendable; workspace and caller ledgers are exclusive inout. Array COW publication preserves prior states; next mutation may copy bounded retained capacity. No shared mutable cache, target-specific isolation or unsafe borrow. Immutable model owner keeps identity/geometry/materials alive.

## Failure, Concurrency, and Constraints
GranularError retains typed Core/Numerical/Collision/Contact/Runtime failures. Supplier inout work remains actual supplier evidence; no guessed conversion into numerical arithmetic. Independent supplier invocation cap applies before calls. Stop once on failure; no retry/fallback. Non-sphere/dynamic finite-mass boundary/instant-impact/antipodal transport callable paths explicitly fail with INCOMPLETE_IMPLEMENTATION markers.

## Verification and Change Impact
Tests execute two-sphere collision/momentum, settling, moving-plane shear/torque/work, cohesive attraction, seeded weighted distribution/replay, and invalid/capacity/cancellation/supplier failures. Numerical success alone is insufficient. Changes invalidate module/root selected profile proof; no independent build by this owner.

### Selected AF17 execution evidence

Native friction/cohesion/rotated-plane/common-port cases passed. Original public profiles execute actual sphere witness/law binding; frictional/cohesive Native oracles are not generalized to all profile paths. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
