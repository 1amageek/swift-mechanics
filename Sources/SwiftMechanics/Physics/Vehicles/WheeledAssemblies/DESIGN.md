# Wheeled Assemblies

## Purpose and Scope
Parent: [Vehicles](../DESIGN.md). Own EX001's selected spatial single-track, six-body wheeled assembly: a floating chassis, two suspension carriers, rear wheel, front steering knuckle, and front wheel. Own actual driver-to-effort composition, original rigid acceleration/query, and bounded explicit evolution. The selected Native path has historical H2 evidence; fresh AF38 matching committed-supplier behavior and individual registration are pending at the [qualification owner](../../../../../Verification/WheeledAssembliesQualification/DESIGN.md#af38-fresh-qualification-boundary). Two wheels are a single-track assembly, not a four-wheel vehicle, tire law, contact solver, or full-vehicle validation.

## Responsibilities and Boundaries
The caller supplies an actual qualified compiled model, calibrated body inertias/geometry, spring/damper laws, servo, affine driveline and limits, constant gravity, and time-valid physical wheel road wrenches. Model compilation retains issuance authority; dynamics retains original mass/bias/force/energy authority. This child never synthesizes road traction, normal loads, friction, tire slip, rolling constraints, or empirical calibration. It reports actual suspension effort redistribution, chassis acceleration/pitch motion and total momentum. Supplied normal forces are explicitly supplied loads, never solved load transfer.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Vehicles](../DESIGN.md) | parent | Vehicle domain boundary | Parent owns registration and qualification |
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | Physical vectors, mass properties, quaternion body-rate integration | World linear and body angular root velocities differ |
| [Model](../../../Modeling/Model/DESIGN.md) | depends on | Original body/joint identities and fixed anchors | No guessed coordinate insertion order |
| [Compiler](../../../Modeling/Compiler/DESIGN.md) | depends on | CompiledMechanicalModel.makeState/evaluate | Consume public producer; never construct its sealed state |
| [Loads](../../Loads/DESIGN.md) | depends on | ScalarLoadEvaluating, PolynomialSpringDamper | Explicit supplied coefficients and domains |
| [Actuation](../../Actuation/DESIGN.md) | depends on | DriveEvaluating and ActuationTransmitting | Preserve original servo clipping/state and affine power residual |
| [Dynamics](../../Dynamics/DESIGN.md) | depends on | RigidEquationComputing, RigidDynamicsSolving | Original physical residual, inertia, power and momentum |

## Architecture
```text
actual compiled six-body tree + calibrated laws + original immutable state
    -> normalized driver inputs -> original steering servo / ideal affine torque splitter / dry brakes
    -> original suspension laws + explicit held world wheel road wrenches
    -> original rigid mass/bias/known-force assembly -> original forward solve
    -> actual acceleration, body motion, inertial wrench, energy and momentum
    -> explicit candidate evolution -> original endpoint mechanics -> residual gates
    -> new immutable state + receipt, or typed failure with unchanged source state
```

## Contracts and Invariants
Admit exactly six dynamic spatial bodies, five scalar dynamic joints, spatial-floating dynamic root, no descriptor features/extensions or prescribed anchors. Topology is chassis→rear carrier→rear wheel and chassis→front carrier→front steering knuckle→front wheel. Suspension axes are local +Z, steering local +Z, wheel spins local +Y. All anchors are fixed with identity rotations; suspension parent anchors have zero Y and front X greater than rear X. Root q is world XYZ plus unit quaternion; root v is world linear XYZ plus body angular XYZ. Canonical joint ID/ranges supply every scalar index; 12 q/11 v follows this selected topology.

Suspension effort is the original scalar response, `-(k2*x+k4*x^3)-(d1*v+d3*v^3)`; stored energy and dissipated power are original response values. Chassis receives the equal-and-opposite internal suspension, steering and wheel efforts through actual tree Jacobians. No chassis external motor/brake reaction is omitted or added twice.

Driver throttle ∈[-1,1] commands a bounded shaft effort in Nm. The original affine transmission has rotation output, zero prescribed drift, and nonzero gradients only at wheel-spin velocities; its power-conjugate torques are an ideal fixed torque splitter, not a gear constraint/differential/engine model. Steering uses the original `.position` servo and its actual state, filter, bounds, clipping and anti-windup. Driver front/rear brake ∈[0,1] gives `-B*sign(relative wheel spin)` Nm. At applied braking, zero spin and sign-crossing candidates fail explicitly; no invented static friction or low-speed smoothing. Endpoint brake power must remain nonpositive.

| Supplied quantity | Units / declared validity |
|---|---|
| Body properties, anchors | kg, m, kg m²; original validated inertia and fixed geometry |
| Suspension rest/displacement/rate | m / m / m s⁻¹; original law's explicit range |
| Suspension k2/k4/d1/d3 | N m⁻¹ / N m⁻³ / N s m⁻¹ / N s³ m⁻³; no defaults introduced |
| Shaft/brake effort and steering servo | Nm and original rotational-servo gains/state domains |
| Wheel-only affine gradients | Dimensionless torque/rate ratios; zero at all non-wheel entries |
| Root and wheel speed limits | m s⁻¹ / rad s⁻¹; explicit caller calibrated domain |
| Road force/torque/lever arm | N / Nm / m; explicit maximum input validity |
| Power/energy/momentum tolerances | W / J / kg m s⁻¹ / kg m² s⁻¹ absolute parts; dimensionless relative parts <1 |

Calibration provenance identifies the caller's engineering calibration and revision; no measurement, empirical coefficient, or source-data equivalence is fabricated. The selected assembly equations are composed directly from the cited original public mechanics producers, not an empirical automotive law.

Each road wrench is actual world force/torque about its supplied fixed world reference point, on the named wheel, contact channel, and valid for the requested interval. Admission bounds force, torque and reference-point lever arm, and requires nonnegative world-Z supplied normal force. The caller owns contact existence and compatibility; no height, radius, friction cone or rolling relation is inferred. Original road input retains unknown potential/dissipation; original MechanicalEnergy therefore may report unavailable potential. This child separately sums original kinetic energy, original gravity potential and original two spring potentials for its stored-energy gate. It never fills unavailable road potential with a success value.

The original equation is `M*a+b=known forces` with zero additional solver drive (actuator contributions already included). Original physical residual must be accepted. Instantaneous `Kdot = original ForceBudget.actualPower` is gated. External force is summed supplied road forces plus total mass times supplied constant gravity; external torque about world origin includes supplied wrench reference moments and actual gravity COM moments. Original total momentum differences are gated against interval impulse estimates.

## Runtime Flows
Initialize validates configuration, public compiled state, original servo binding/state and calibration provenance, then seals immutable state. Query evaluates driver servo with dt=0 and original mechanics. Step admits positive bounded dt and source time; advances the original steering servo once; holds its applied effort, original driveline torques and dry brake torques over that step. Evaluate original start mechanics; advance world root position and scalar joint q by start coordinate rate, root quaternion using original body-rate exponential integration, and v by original acceleration times dt. Public makeState validates the candidate; evaluate original endpoint mechanics with held actuator efforts and updated original suspension laws.

Road/motor/steering/brake work and damping loss use endpoint trapezoidal physical powers. These are explicit quadrature estimates, not exact interval work. The original servo receipt defines source/mechanical work from its start sample; preserve it, report the difference from interval steering-power quadrature, and use its original source work in `delta stored - estimated road/motor work - original servo source work + suspension/brake loss`. Gate this residual's absolute and relative tolerance and cumulative absolute accepted defect. Never rewrite the original servo ledger into a different successful value. Linear impulse is exact for constant world force/gravity; angular impulse uses endpoint gravity torque quadrature. Report/gate original momentum residuals. No correction projects state or energy to acceptance. Rejection publishes no candidate state; source values remain unchanged. A subsequent query recalculates control from accepted servo state; an endpoint receipt describes the held effort of the preceding interval.

## State, Ownership, and Lifecycle
Configuration, state, receipts and implementations are immutable Sendable values. State construction is internal; initialization and successful step are the only issuers. State owns its admitted configuration, source stamp, accepted sequence and cumulative defect. Branching from immutable older states is explicitly a caller-owned independent trial, not global accepted-state publication. Numerical/Load/Actuation workspaces are caller-owned exclusive `inout` values and retain charges after failure; the caller must retain the same workspace over its bounded run. A frozen dynamics failure with unavailable supplier work makes that workspace terminal and forbids later successful calls. No retry, budget reset, shared session, callback lock, stream or shutdown resource is introduced.

| Logical storage | Native | WASM | Embedded |
|---|---|---|---|
| Configuration/state/receipts | Immutable Sendable values | Same | Same |
| Work ledger | Exclusive inout local value | Same | Same |
| Shared mutable storage | None | None | None |
| Read/mutation entry | Protocol query / new value issuance | Same | Same |
| Release | Value lifetime | Same | Same |

## Failure, Concurrency, and Constraints
Typed errors preserve original Core/Compilation/Joint/Load/Actuation/Dynamics/Numerical errors without casts or default replacements. Cancellation is explicit and never converted to accepted evolution. Caller limits bound steps, model calls, metadata, original supplier work/storage, road wrench domain, steering/suspension rates and maximum dt. Fixed shape bounds unmetered public kinematic work; every public model producer/evaluate call is counted. Local arithmetic and retained scalar capacity are conservatively admitted separately from supplier ledgers. Work is charged before candidate publication, including rejected trials. Callable unsupported branches carry immediate INCOMPLETE_IMPLEMENTATION markers.

Unsupported: four-wheel/Ackermann assemblies, engine/differential/gear kinematic constraints, static brake holding or brake spin reversal, tire/terrain/contact closure, changing topology, prescribed anchors, other charts, nonlinear gravity, generic integrators, full-vehicle stability/performance claims.

## Verification and Change Impact
Original implementation evidence: `Tests/MechanicsDynamicsTests/RigidMechanicsTests.swift:4-30` exercises offset-COM rotated asymmetric floating mass/bias/forward/original energy/momentum; `Tests/MechanicsJointsTests/JacobianTests.swift:5-68` exercises articulated floating revolute/prismatic directional Jacobian and bias; `Tests/MechanicsCoreTests/GeometryTests.swift:54-74` independently checks body/world rotation integration and repeated quaternion evolution; `Tests/MechanicsActuationTests/DriveTests.swift` exercises actual position servo, clipping/filter/history/failure; `Tests/MechanicsActuationTests/TransmissionTests.swift:5-13` exercises original affine virtual/prescribed power and frame/zero-gradient failures; `Tests/MechanicsLoadsTests/PassiveLawsTests.swift:4-20` independently differentiates spring potential/effort and verifies dissipated power/domain refusal. `Tests/MechanicsActuationTests/ActuationFixtures.swift:33-49` uses the actual ReferenceMechanicalCompiler producer with original bodies/joints/inertia and explicit capacity policies. Public CompiledMechanicalModel.makeState/evaluate call the original TreeKinematicsEvaluator and issue sealed compiled states. These establish supplier domains, not this new assembly's qualification.

The linked child behavioral owner independently verifies selected-tree suspension/pitch response, acceleration/braking under supplied road wrenches, equal/opposite internal efforts, steering actuation, original momentum/energy and residual rejection, zero/crossing brakes, immutable failed trial, cancellation/work limits and terminal unavailable supplier work. Fresh selected Native qualification passed against the exact2387 common producer described by the linked verification owner. Ordinary/Embedded and broader vehicle behavior remain separate. Supplier contract changes invalidate directly dependent gates; parent owns integration, indexes and registration.

### AF38 Committed Supplier Boundary
Fresh qualification uses committed `d30b585fdb0cd8fb1ab1104d861b03fbf55ecb26` lower suppliers and original14 assembly sources. The historical2353H2 module is not an input. Immediate public constructor/evaluation routes and exact committed hashes are recorded by the qualification owner; live PhysicalRigidDynamicsSystem and RigidEquationComputing WIP differs from this committed authority and is not silently mixed. Initialize, real force assembly/forward solve, physical acceleration/energy/momentum, held-step source work and typed failure-prefix paths were read without identifying a new concrete owned defect. Original equations, work, tolerances, immutable state issuance and genuine unsupported markers remain unchanged. Fresh Native8/public7 plus original awaited cancellation passed. Receipt `41345b0816a1e81eeeac5996e46b0d7ea7f231ef14cbeb65bcbe1023ea8129f4` and fixture object/link inspection `92a7559694493fa2f998db7393c3ecf28c091c288b748751d3ce0564ba35c943` bind the original14/fixture7 to the exact2387 common source/object/module/dylib before and after execution; the linked verification design owns execution details. This selected Native evidence does not qualify other common-producer cohorts. Supplied support normals remain external inputs; no contact, traction, tire/terrain or solved load-transfer equivalence is introduced.
