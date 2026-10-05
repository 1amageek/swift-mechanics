# Physical time parameterization

## Purpose and Scope
Parent: [Planning](../DESIGN.md). Own the selected OP-008 physical retiming query. No children. The admitted domain is a spatial fixed-root articulated tree with only fixed or single-axis prismatic joints and fixed anchors. The path is an explicitly identified sequence of Euclidean joint-coordinate waypoints. Each segment uses rest-to-rest quintic interpolation and stops at every waypoint. Selected original Native and canonical1872 behavioral qualification is owned by [TimeParameterization qualification](../../../../../Verification/TimeParameterizationQualification/DESIGN.md). All14 implementation files and the five qualification Swift files remain unchanged. Ordinary/Embedded runtime and general-domain retiming remain separate open gates.

## Responsibilities and Boundaries
Own topology admission, interpolation, duration selection, continuous signed-limit certificates and physical query replay. Consume IM06 tree kinematics and IM15 original rigid equations. Do not infer dynamics from caller samples or accept an arbitrary equation provider as a constancy witness. Held external forces are explicit constant generalized applied forces in the declared coordinate layout. Uniform gravity must have zero gradient and zero explicit time derivative. Constraints, contact, body-wrench loads, moving anchors, rotating charts and curved interpolation require another qualified domain.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Planning](../DESIGN.md) | parent | Query ownership | Query never publishes accepted dynamics | Source availability is not qualification |
| [ArticulatedTrees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Tree layout and actual framed evaluation | Fixed orientations and translational Jacobians | Inspect each axis and anchor, not joint names alone |
| [RigidEquations](../../../Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | Actual mass, gravity and original inertial force | Original physical effort certificates and samples | Spatial positive-velocity domain only |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork bounded ledger | Scalar/work accounting | Include simultaneously retained query/program storage |

## Architecture
```text
identified spatial tree + inertias + static gravity + held generalized loads
  -> topology/chart admission -> actual IM06 snapshot -> IM15 original equations
waypoints + physical signed limits + bounded policy
  -> each delta and original inertialForce(delta) -> analytic quintic extrema
  -> bounded duration -> continuous segment certificate -> immutable program
program + caller time
  -> owned quintic sample -> actual IM06/IM15 replay -> checked physical sample
```

## Contracts and Invariants
Admission requires fixed root, spatial bodies, fixed anchors and each nonfixed manifold to have exactly one prismatic axis, qdot=v, matching q/v coordinate ranges. Recursively all body rotations are constant; angular columns and angular velocities are zero. Consequently translational columns, COM offsets and M are constant, all Coriolis/centripetal terms vanish, and uniform static gravity and held generalized loads are constant. This is a structural proof across the entire path; a rest sample only supplies actual coefficients. The actual reference inertial bias must also be exactly zero or admission fails.

For normalized u, f=10u^3-15u^4+6u^5, f'=30u^2(1-u)^2 and f''=60u(1-u)(1-2u). Continuous maxima are 15/8 and 10/sqrt(3); acceleration extrema occur at (3 +/- sqrt(3))/6. For segment displacement d and h>0: q=q0+d*f, v=d*f'/h, a=d*f''/h^2 and required actuator effort=originalInertialForce(d)*f''/h^2-gravity-heldApplied. Certificates contain full signed ranges and original physical coefficients. Limits are enforced on the full closed interval, including static waypoint effort. No sample grid proves an inter-knot constraint.

Duration is the largest analytic lower bound for this interpolation and stop policy, enlarged by the square of the caller's floating-point safety factor and nextUp. Representable clock rounding can further enlarge it, and the effective duration must still pass all bounds. This is not global time optimality. Certificates apply one safety factor to evaluated extrema and use outward endpoint rounding; the second duration factor leaves a rounding margin. Actual query replay must satisfy original signed limits and agree with the analytic effort within an explicit supplier tolerance; discrepancy fails instead of publishing a sample. Floating-point certificates are analytical envelopes under this declared numerical policy, not formal interval arithmetic proofs. Zero limits that prohibit required motion or static gravity fail as infeasible. Repeated waypoints have positive minimum duration and a constant pose.

Source ID, path ID, tree revision, world frame, complete coordinate layout, origin time, held-load convention, interpolation and waypoint stop policy are retained. Program constructors are internal; callers cannot forge admission or certificates. Supplied IDs identify caller-owned sources; the retained immutable model is the authority and queries never substitute another source.

## Runtime Flows
Retiming checks admission and all input bounds before allocation, assembles one zero-motion reference source, computes each original segment inertia coefficient, chooses one bounded duration, then checks the whole certificate. Query chooses the first segment whose end includes the requested time; shared waypoints give identical q,v,a and static effort from either side. Outside the closed clock domain is a typed failure. No extrapolation, clamping to a different state, fallback or partial program publication.

## State, Ownership, and Lifecycle
All public inputs, programs, certificates and samples are immutable Sendable values on Native, WASM and Embedded. Synchronous workspace belongs exclusively to the invocation. No shared mutable cache, target-dependent conformance, unsafe pointer or accepted-state mutation. Program retains complete immutable physical source, policies and path storage for its lifetime. Caller supplies the same explicit NumericalWork and LoadWork ledgers to construction and replay; suppliers use bounded nested numerical ledgers with retained-storage reservations and are absorbed even on failure.

## Failure, Concurrency, and Constraints
Typed failures cover invalid shape/identity/policy, unsupported chart, nonfinite/underflow arithmetic, static/motion infeasibility, duration/time limits, caller/Task cancellation, supplier failure and work/storage exhaustion. Caller bounds bodies, coordinates, waypoints and query work through policies and supplier admission. Counts use checked integer arithmetic. Scalar storage accounts retained path, certificates, model kinematic columns, original system and local arrays; supplier peak storage is additional, not a replacement. Work is O(B*N^2+S*B*N+S*N), storage O(B*N+N^2+S*N); each replay is O(B*N^2). No unbounded search or retry. Every segment/coordinate and supplier boundary polls cancellation. Tiny durations with nonfinite reciprocals, or time addition that cannot represent progress, fail explicitly. Finite polynomial and endpoint arithmetic is checked before publication.

## Verification and Change Impact
The [qualification owner](../../../../../Verification/TimeParameterizationQualification/DESIGN.md) fixes independent coupled-prismatic physical equations, rotated anchors, gravity/held applied forces, full polynomial extrema, analytic duration, knots/clock/source metadata, typed refusals, work/storage and cancellation witnesses. Its shared synchronous cases are portable-ready; Native execution is the first behavioral gate and does not qualify unexecuted WASM/Embedded profiles. Root owns registration, integration and Git. Supplier/topology/interpolation changes invalidate dependent certificates and require renewed behavioral qualification.

### Selected Native behavioral evidence
The preceding pending Native behavioral gate is closed by [TimeParameterization qualification](../../../../../Verification/TimeParameterizationQualification/DESIGN.md): pinned Swift 6.4.0 release with MacOSX27.0 SDK passed eight focused tests, including awaited Task cancellation, and the same seven synchronous public cases. Independent coupled mass, rotated anchors, gravity and held loads, closed-interval quintic extrema, signed analytic duration, original required-effort replay, source/clock metadata and typed resource failures were exercised. All 14 production sources and the immutable Native2363 objects/module metadata matched SHA after execution; no production repair or numeric-contract change was needed. Actual compiler/source/object/link evidence is retained in `.build/af35-time-parameterization-qualification/behavioral-handoff.json`. This original evidence applies to its selected Native graph. The canonical1872 closure below is additional evidence for the unchanged selected contract; WASM/Embedded runtime and general curved/rotating retiming remain separate open gates.


### Canonical registration preparation boundary
The selected original Native8/public7 evidence above is retained. Full registered graph preparation is owned by [TimeParameterization qualification](../../../../../Verification/TimeParameterizationQualification/DESIGN.md); it waits for the actual RollingRelations predecessor commit and warm source/object/module proof before binding1858+14=1872. No14 Swift implementation, unsupported-domain marker, public contract, interpolation, oracle or numerical policy changes are made. Root executed that exact prepared graph; the Native-only closure below records its actual source/object/module/runtime proof.

The preparation predecessor is committed `d4e4afc881a8f85272de607d0b87ed152d7d29fa` (complete1858 source/object/module graph and selected Rolling Native8/public7 composition). The qualification owner binds the explicit qualified composite receipt and preserves the first partial fixture-registration failure as failure evidence. Exact unchanged Time14/fixture5 are prepared for1872; preparation itself ran no Time compiler or runtime; the subsequent root execution is recorded below.


### Registered canonical Native1872 closure
Root executed the complete committed1858 graph from `d4e4afc881a8f85272de607d0b87ed152d7d29fa` plus these unchanged14 files. Pinned Swift6.4.0 release with MacOSX27.0 SDK and macOS13 deployment target actually emitted the complete module and all14 added primaries; sourceCount1872. Eight original focused tests, including awaited Native Task cancellation, and the unchanged seven synchronous public cases passed. The public four-fixture caller linked the same1872 objects as the actual test bundle; original public stdout was byte-identical. All1872 source/object identities, three module metadata files and selected14 production/four test fixture bindings matched after link/runtime. No production or fixture Swift, oracle, tolerance or selected physical domain was changed.

Authoritative Native receipt is `.build/af35-time-parameterization-qualification/registration/canonical-native-receipt.json` SHA `ac07464ea2d30dc65442996e2d411232bed4088089d28d8703c6118fb9aaa307`; complete object/module inventory SHA `6541058debc733849a6aa28f5c7330c699b9cac4662bfa25090ee9fca07824f6`. This closes selected canonical Native registration, not general1872 physics, portable runtime or global time optimality. Strict public signing passed; the test bundle's existing resource-signature discrepancy remains explicit despite its eight passing behavioral tests. Root owns commit, parent registration and integration; the unsupported general-chart marker remains unchanged.
