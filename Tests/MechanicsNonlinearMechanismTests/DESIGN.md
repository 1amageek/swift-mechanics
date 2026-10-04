# Nonlinear mechanism verification

## Purpose and Scope
Test owner for [NonlinearEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/NonlinearEvolution/DESIGN.md), with no children. Retain existing quadratic behavior and prove the new actual body-frame force evolution through the registered public SwiftMechanics module.

## Responsibilities and Boundaries
This target owns independent physical fixtures/oracles and success, failure, endpoint and replay witnesses. Root owns target registration, original-profile execution and task integration. The tests use real compilation, rigid mass, constraint and Runtime paths; they never fabricate a dynamics system or internal accepted record.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [NonlinearEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/NonlinearEvolution/DESIGN.md) | used by | quadratic/geometric facades, projected advance, physical result | Primary behavior under test | Require actual execution, not type presence |
| [GeometricRelations](../../Sources/SwiftMechanics/Physics/Constraints/GeometricRelations/DESIGN.md) | depends on | immutable builtin relations and original samples | Real frame constraints | Full physical axis cross is independently checked |
| [ManifoldProjection](../../Sources/SwiftMechanics/Physics/Constraints/ManifoldProjection/DESIGN.md) | depends on | local tangent assembly | Position consistency | No closest-point claim |
| [Foundation verification](../../Verification/FoundationVerification/DESIGN.md) | coordinates with | exact original profile evidence | Public Native/WASM/Embedded qualification | Native dedicated mixed evidence does not qualify other profiles |

## Architecture
```text
independent circle / rod sin-cos / quaternion / moving target oracles
    -> real compiled models -> public equations -> common projected evolution
    -> actual mass/reaction/energy -> Runtime endpoint/history/replay
fault suppliers -> original source/ledger acceptance -> unchanged accepted prefix
```

## Contracts and Invariants
| Invariant | Independent behavioral oracle |
|---|---|
| Quadratic original position/velocity and redundancy | Cartesian circle norm and q dot v after twenty seconds |
| Quadratic original acceleration and energy | Unit mass centrifugal force, gravity radial equation and mechanical energy |
| Non-polynomial actual revolute loop | Fourbar independent sin/cos g, first and second derivatives |
| Reaction and physical energy | Independent geometric J-transpose multipliers, zero autonomous reaction power, rod kinetic energy vs constant torque displacement |
| Numeric order | Circle analytic fourth-order refinement; actual fourbar state refinement |
| Mixed q/v and centripetal terms | Root/sixDOF/spherical quaternion half angles, strict norm, moving x-axis full cross/rate/second derivative |
| Correction energy accounting | Rod energy before/after position retraction separately from velocity impulse kineticEnergyChange |
| Analytic time law | Independent moving target q/v/a in SI seconds |
| Strict initial vs RK correction | Invalid external quaternion rejected; bounded stage correction explicitly reported |
| Accepted state and history | Exact public associatedHistory and checkpoint/restart equality |
| Rejection and opaque failures | Adaptive reject, late reset success/failure/cancel, unchanged physical/history/RNG prefix and no unknown retry |
| Complete source binding | Genuine producer systems with changed pose/inertia/load and changed-q acceleration at equal time/v rejected |
| Canonical metadata binding | Same facade identity with different drive/chart bound cannot reuse contributor |

The mixed fixture uses equal relative sphere/sixDOF spin with a moving physical x-axis: its axis rate and centripetal second derivative are nonzero while full original physical closure derivatives vanish. Canonical public joint ID/ranges determine all chart offsets. No test assumes caller insertion order equals compiler layout order.

## Runtime Flows
Registered focused Native execution follows one stable source/test freeze. Public profile probes consume the same public facade requirements. Original endpoint failures are invoked inside actual Runtime trials after drawing RNG so rollback checks include random state. Rejected manual physical witnesses leave accepted state untouched. Replay restores actual serialized checkpoint data.

## State, Ownership, and Lifecycle
Each test owns its model/session/suppliers. Session shutdown is deferred. Physical witness capture uses the existing identical Mutex<NonlinearMechanismState?> and withLock operations on every target. No static shared resource or platform-dependent mutable storage is added.

## Failure, Concurrency, and Constraints
Every test has an explicit time limit. Root supplies a process timeout and exact Swift 6.4.0 toolchain for registered execution. Supplier reset/cancel flags are immutable and selected by physical time. Opaque wrappers return genuine lower-produced records; unknown failed work cannot be turned into successful retry.

## Verification and Change Impact
Existing thirteen Native tests and AF20 original-profile paths were qualified before IM16.10. Their original snapshot evidence remains in [Foundation verification](../../Verification/FoundationVerification/DESIGN.md). New IM16.10 evidence is pending stable registered execution; source presence and the interim topology compile do not qualify new physical behavior. Renew affected quadratic/shared-engine and geometric tests once after convergence, then root qualifies the actual original public profiles. No copied dependency package or temporary manifest is used.

AF23 MovingBaseEvolutionTests/MovingBaseFailureTests own regular-axis moving-base coupled rotor q/v/a/reaction, full K/momentum/virtual+prescribed work, mixed quaternion stages, source/law/history association, exact replay and supplier failure prefix. Registered-graph focused/profile execution is root-owned and pending the frozen handoff.

ColdAggregateValidationTests owns the reopened cold solver aggregate arithmetic/iteration admission counterexample. A real delegated solver spends valid local prefixes; the test checks one combined callback envelope, terminal known-prefix capacity/failure and no callback when four local seeds cannot be admitted.

## AF24 planar evolution evidence
Use actual compiled planar fourbar geometry and original mass/COM/Iz. Independent sin/cos closure, velocity, acceleration, rod kinetic energy/torque work, refinement and long run exercise the common projected engine. Exact fresh restart/replay, forged tangent acceleration, changed Iz, wrong physical source, cancellation and failed supplier ledger preserve accepted bytes/RNG. Production contract belongs to [NonlinearEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/NonlinearEvolution/DESIGN.md#af24-planar-physical-composition); individual body reaction allocation belongs to its separate owner.

The first registered affected Native run passed 39 cases in eleven suites on macOS 27 arm64 with Swift 6.4.0 release, `-j 4`, `.build/ar01-native` and a 240-second command bound (`.build/af24-upper-native-tests.log`). Actual original physical constrained/evolution success and refusal paths executed. Original WASM/Embedded qualification remains owned by IM.IM16.25.

### AF25 selected proof ownership
AF25 PrescribedRootEvolutionTests / PrescribedRootFailureTests / PrescribedRootAggregateTests own complete root-only and dynamic-descendant planar/spatial selected behavior. Independent scalar Newton-Euler and internal-motor oracles verify original efforts, COM/spin K/Kdot and integrated work, actual q/v/a/axis closure, refinement, exact canonical endpoint/history, cold replay and failed mutation prefix. Faults execute actual producers for wrong source/acceleration and seeded ledger reset/cancel/unknown work; caller capacity/conflict and changed same-ID law/inertia are exact typed refusals. Aggregate evidence uses one identical Mutex owner across targets; no callback runs under its lock. Root executes the registered graph and original profiles after source freeze.

### AF26 quadratic cold authority proof

Dedicated source/test implementation is frozen; owner-isolated focused Native execution passed eight tests in two suites. The sole production contract is [NonlinearEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/NonlinearEvolution/DESIGN.md#af26-source-bound-quadratic-cold-authority). Root owns upper sleep/wake migration, shared registration/integration, original profiles and commits; the lower owner runs bounded isolated Native commands. existing legacy/geometric/root evidence remains unchanged.

Use actual fixed-root spatial mass-2 Y-prismatic A/B/C, original A-B/B-C rows and drive [4,-4,0], resting q/v/a. Derive canonical offsets from compiler joint IDs/ranges. A public subtree release replaces A with sixDOF; explicit target rows/drive retire A-B/A effort and retain B-C/B=-4. Independent scalar Newton equations give A a=0, B=C=-1, without using returned diagnostics as oracle.

| Invariant | Actual behavioral proof |
|---|---|
| Physical source identity | Same stamp/chart/drive/resting state with changed mass changes the strict descriptor and rejects old history; legacy signature remains compatible. |
| Original force, every sequence | Accept consistent source/target at zero and later; reject row-consistent force-wrong stored a and free forward B=-2/C=0. Exercise actual sixDOF q7/v6, quaternion/Ndot and original retained rows. |
| Immutable target evidence | Wrong target descriptor/layout/stamp refuses; valid reconciliation preserves all q/v/time/revision bits and consumes only actual producer evidence. Root may compile-probe inaccessible token creation from an unrelated component. |
| History and required law source | Actual public Integration records bind time/full point/source signature/global steps, including source+1 target. Missing/altered/stale/future records and required registry omission/duplicate/unknown/law mutation refuse. |
| Bounded irreversible work | Real delegated evaluator/solver success and failure preserve seeds/known prefixes; reset/unknown work is terminal, capacity prevents unadmitted entry, late cancellation prevents issuance. Four cold ledgers share one admitted ceiling. |
| Whole-prefix rollback/replay | Genuine Runtime trial draws RNG before contextual failure; compare full checkpoint bytes/history/RNG. Fresh equivalent source-bound owner restores encoded saved state, advances actual projected evolution and replays exactly. |

No fake control, copied producer, manufactured accepted state, raw IntegrationHistory or projection that repairs saved input is used. Lower tests prove physical evidence/context; exact upper catalog/publication is its own owner. Failed admission/reconciliation cannot change the accepted prefix while caller work remains an irreversible failed prefix. Tests use individual availability guards inside undecorated Test/Suite functions, explicit time limits and root command timeout. New supplier captures, if needed, are operation-local identical Mutex owners across Native/WASM/Embedded with callbacks outside locks. One scoped source/test review plus causal repairs precedes frozen focused qualification in committed baseline 1fbf8f9 with only the owned component/test overlay. No producer or manifest is substituted; later shared-graph/profile integration remains root-owned. Design presence is not proof completion.

AF26 dedicated files: QuadraticColdFixture.swift, QuadraticColdTests.swift, QuadraticColdFaultSolver.swift and QuadraticColdFailureTests.swift. Eight guarded Test functions exercise the preceding actual paths. Required catalog evidence uses the real FixedActuatorContinuationCodec and ActuatorRuntimeContributors with a scalar joint binding, including changed lawRevision; it supplies no actuator topology adapter. The real cold solver reset witness consumes later admitted ledgers before resetting the first so losing their known prefix is observable. No isolated success is generalized to later shared/profile integration.

AF26 isolated actual Native evidence is canonical in [NonlinearEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/NonlinearEvolution/DESIGN.md#af26-isolated-native-qualification). The final command passed all eight QuadraticCold tests with exit zero; the independently retained-row target, original required Actuator validator, byte/RNG refusal and fresh-owner projected replay all executed. The sole executed red finding was an incorrect changed-mass expected error code; the test now requires the original Integration signature owner's exact incompatibleContinuation refusal, while global sequence mismatch remains invalidContributor. Narrowing removed only unrelated copy test registrations after bounded cold compile costs; original production and this target declaration remained exact. No Native evidence is generalized to original WASM/Embedded or the canonical upper composition.


## AF26 trajectory evolution proof contract

The owner tests [NonlinearEvolution's exact additive trajectory contract](../../Sources/SwiftMechanics/Physics/Mechanisms/NonlinearEvolution/DESIGN.md#af26-knot-aware-trajectory-evolution-contract). Root's independent public composition contract is [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md#af26-upper-independent-public-evidence-contract). No new production or behavior is qualified by this design-only handoff.

New test files: `TrajectoryEvolutionFixtures.swift`, `TrajectoryEvolutionTests.swift`, `TrajectoryEvolutionFailureTests.swift` and separate primary supplier types `TrajectoryFaultSampler.swift`, `TrajectoryFaultBaseSampler.swift`, `TrajectoryFaultBoundaryQuery.swift`. Actual compiler sources match the declared program frame/parent/layout/time/initial q/v/a; abstract lower fixture IDs are not reused as a physical association shortcut. Existing quadratic cold files and unrelated reaction/sleep/topology tests are not modified.

| Invariant | Actual independent behavioral evidence |
|---|---|
| Root-only planar/spatial physical authority | Nonzero COM and inertia, nonidentity orientation, world COM acceleration; original F=m aCOM and origin torque=Iworld alpha+omega cross(Iworld omega)+r cross F. Independently compute K and Kdot, root effort/power and zero-load work=delta K. |
| Dynamic descendants | Real regular-axis coupled rotors on the prescribed root with internal relative-coordinate drive; independent common acceleration, root effort and drive/root power balance in both admitted dimensions. |
| Harmonic chart/stage math | Scalar sine/cosine derivatives and noncommuting Rx reference rotation, independent body omega/alpha and quaternion qdot; actual full ODE point/stages remain source-bound. |
| C2 knot | Integrate across a real t=1 polynomial knot with a proposed step spanning it. Capture actual requirement query/accepted time, prove endpoint exact knot, right-law jets, one accepted sequence increment and strictly next interval; no reset/event/interpolation. |
| Endpoint/history/replay | Actual final derivative, original acceleration/reaction/K/power and exact original Integration associatedHistory; same-owner and fresh equivalent law/model/equation/session replay compare complete physical state and checkpoint bytes. |
| Source refusal | Changed law under the same revision/identity, changed inertia/frame/time/q/v/a or forged tangent acceleration refuses original force/chart admission. Changed future-only coefficients require the original exact incompatibleContinuation code. |
| Supplier/aggregate bounds | Real delegated new samplers/query preserve local prefixes; wrong nil/later knot and genuine wrong-source sample reject. Reset on success/failure, unknown work, capacity before callback and late cancellation preserve work and prevent retry/publication. Existing cold four-ledger ceiling stays enforced. |
| Whole-prefix rollback | Actual trial draws RNG before failure; compare complete accepted physical/history/checkpoint/RNG prefix. Failure work remains irreversible while publication rolls back. |
| Compatibility | Legacy facade initialization/injected supplier authority, old quadratic sample/signature bits and old custom smooth conformer default no-knot witness remain exercised. New geometric facade explicitly uses its boundary witness through any ProjectedMechanismEquations. |

Fixtures select explicit caller linear capabilities rather than silently symmetrizing or falling back, and use unchanged original physical tolerances. New tests are owner-local and use identical Mutex captures across targets; no callback is invoked while locked. Exact lower unsupported derivative seam is a refusal before runtime publication, not proof of real discontinuity events. Full KI-006 remains open for that domain.

After one owned review and finding-only repairs, bounded exact Swift6.4.0 Native tests execute in root-prepared `.build/af26-upper-independent-trajectory` with owned component/test overlays. Preserve incremental objects and report the actual registration graph, command, counts/logs and freeze digest. Root performs canonical cumulative Native and raw original Native/WASM/Embedded execution plus every-write128KiB guards once after all sources freeze. No isolated Native proof is generalized to a profile not executed.
