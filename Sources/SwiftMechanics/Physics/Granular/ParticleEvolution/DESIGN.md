# ParticleEvolution

## Purpose and Scope
Explicit compliant particle evolution and physical acceptance. Initial admitted implementation domain; behavioral/profile qualification pending. Parent [module](../DESIGN.md); no children.

## Responsibilities and Boundaries
Own frozen-geometry kick/drift update of all sphere centers and world angular velocities, force/couple accumulation, plane reactions and original impulse/work acceptance. Pure required GranularEvolving operation returns an immutable complete state; accepted input is never mutated. Runtime transactional publication is a downstream composition responsibility.

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
vNext=v+hF/m, omegaNext=omega+hTau/I, xNext=x+h*vNext. Isotropic spheres have no gyroscopic torque. Gravity contributes m*g. Equal/opposite contact force and couple applied at the common point; plane wrench torque is about plane proxy origin. Prescribed plane velocity is u+omegaBoundary cross (point-origin). Per-particle original m*DeltaV-hF and I*DeltaOmega-hTau residuals and independently contact/gravity midpoint work versus DeltaK are required acceptance evidence. Momentum tolerances have Ns/Nms units, energy tolerance J, with caller reference scales/relative tolerance.

## Runtime Flows
Constitutive stored energy/dissipation at old geometry and updated tangential trial are reported separately; contactStoredEnergy is this mixed frozen-geometry contact evaluation, not energy at returned centers. Frozen geometry integration can change total energy; no exact total-energy conservation or stability claim. Caller dt and refinement own truncation/stiffness admission. CPU Float64 only. NumericalWork counts conservative primitive scalar-operation bounds (pair block 2048, integration 256/particle, acceptance 1024/particle and 1024/contact, metadata UTF8 2/byte), charged before the bounded phase; string equality follows per-invocation scans of both operands. Supplier arithmetic/storage stays in its native ledger; combined peak admission is the sum of separately caller-selected Numerical/Collision/Contact storage limits, not guessed conversion. Logical scalar-slot weights bound initialized records and retained Array capacities; allocator rounding and OS bytes are not claimed. NumericalWork counts UTF8 traversal before equality; caller particle/boundary/history/neighbor capacities and scalar storage before allocation, overflow checked. Local workspaces account retained capacities plus trial/output initialized records; no unsafe storage or target conditionals. Cancellation at each admission/pair/particle and final publication.

## State, Ownership, and Lifecycle
Inputs/results are immutable Sendable; workspace and caller ledgers are exclusive inout. Array COW publication preserves prior states; next mutation may copy bounded retained capacity. No shared mutable cache, target-specific isolation or unsafe borrow. Immutable model owner keeps identity/geometry/materials alive.

## Failure, Concurrency, and Constraints
GranularError retains typed Core/Numerical/Collision/Contact/Runtime failures. Supplier inout work remains actual supplier evidence; no guessed conversion into numerical arithmetic. Independent supplier invocation cap applies before calls. Stop once on failure; no retry/fallback. Non-sphere/dynamic finite-mass boundary/instant-impact/antipodal transport callable paths explicitly fail with INCOMPLETE_IMPLEMENTATION markers.

## Verification and Change Impact
Tests execute two-sphere collision/momentum, settling, moving-plane shear/torque/work, cohesive attraction, seeded weighted distribution/replay, and invalid/capacity/cancellation/supplier failures. Numerical success alone is insufficient. Changes invalidate module/root selected profile proof; no independent build by this owner.

### Selected AF17 execution evidence

Native collision, shear, angular momentum, 6000-step settling and time-refinement oracles passed. Original public profiles execute two-sphere impulse/original-work and rejection paths; prescribed-plane evolution is separately Native evidence. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.
