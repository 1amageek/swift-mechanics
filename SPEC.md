# swift-mechanics specification

Status: proposed requirements, revision 0.1, 2026-10-03. **Every requirement below is `planned`; none is implemented or behaviorally verified.** This is the canonical functional and acceptance contract. [DESIGN.md](DESIGN.md) owns the proposed architecture; [SOURCES.md](SOURCES.md) owns source observations.

## 1. Goal and interpretation

Build a Swift engineering mechanics library covering mechanisms, rigid and flexible multibody dynamics, transmission systems, contact, control, optimization and selected coupled engineering systems. A torque-driven gear assembly must produce motion and engineering quantities such as bearing reactions and transmitted torque, with declared physical assumptions and numerical error.

Every requirement row is mandatory for the complete target scope. Delivery gates sequence work; an early gate does not redefine full completion. Required domain-specific extensions may be separately installed products, but remain part of the target. A backend adapter to an existing engine may enable interoperability or serve as a reference; it does not establish implementation of the native Swift solver requirements.

Requirements describe semantics rather than freezing public Swift type names. Public APIs, protocol requirements, ownership, model equations and child designs must be finalized before their implementation. Each implemented requirement must link its design owner, implementation path, applicable capabilities, and behavioral evidence. A declaration or successful compilation is insufficient.

### 1.1 Mechanical levels

| Level | Inputs and resulting claim | Requirements |
|---|---|---|
| Prescribed kinematics | Motion input and geometric constraints; predicts positions and velocities, not load-driven behavior | KI, JT, CN, TR |
| Rigid multibody dynamics | Mass/inertia, forces, actuators and constraints; predicts acceleration and reactions within the selected model | RB, DY, FL, AC, SO, TI |
| Contact dynamics | Collision proxies and contact/material laws; resolves contact forces or impulses and friction | CL, CT |
| Flexible mechanics | Discretization and constitutive law; resolves deformation, stress and rigid/flexible coupling | FX |
| Control and optimization | State, observations, costs, constraints and derivatives; computes controls, configurations or trajectories | SE, CO, OP |
| Coupled applications | Vehicle, particle or fluid models with their own assumptions and budgets | EX |

Ideal gear coupling does not simulate tooth stress, wear, sound, lubrication, friction or loss unless those models are separately enabled. Accurate-looking animation is not evidence for any level.

### 1.2 Scope envelope

The target is finite-dimensional numerical mechanics in 2D and 3D, with declared rigid, compliant, flexible, particle and discretized fluid models. Inputs must be finite, dimensionally consistent and within the chosen model's geometric, material and solver domain. Degenerate or ill-conditioned problems may fail with diagnostics. Success is guaranteed only when the solver's acceptance checks pass, not for every physically imaginable mechanism.

Fracture propagation, arbitrary multiphysics PDEs, fatigue life, gear wear, acoustic propagation, electromagnetic field solving and complete compatibility with every upstream extension are outside revision 0.1. Their inputs/results must not be implied by another capability. The required plasticity, fluid-force and FSI features below retain their explicitly bounded constitutive/discretization scopes.

## 2. Shared contracts

All rows inherit these conditions; their specific failure and acceptance cells add obligations.

### 2.1 Units, coordinates and equations

Canonical storage uses SI: m, kg, s, rad, N, N·m, Pa and J. Conversion boundaries preserve units and reject dimensional mismatch. Right-handed frames, transform direction, spatial vector ordering, quaternion convention and force application point must be published and consistent.

For smooth constrained rigid mechanics, the selected formulation must identify its equation terms:

```text
q_dot = N(q) v
M(q) v_dot + b(q, v, t) = Q(q, v, u, t) + J(q, t)^T lambda
g(q, t) = 0;  J(q, t) v + g_t(q, t) = 0
```

`q` and `v` can have different dimensions. Constraint-coordinate multipliers must be mapped to physically framed reaction wrenches before presenting forces/torques. Contact impulse stepping, regularized soft contact, flexible constitutive equations and fluid discretizations must state their own discrete or continuous equations; they are not interchangeable realizations of the smooth equation above.

### 2.2 Failure vocabulary and transaction boundary

The following are semantic error categories, not a frozen Swift enum: `InvalidInput`, `MissingReference`, `UnsupportedCapability`, `InconsistentConstraints`, `SingularSystem`, `NonConvergence`, `ResourceLimit`, `Cancelled`, `InvalidState`, `IncompatibleData`, and `DerivativeUnavailable`.

Failures carry operation/phase, affected IDs, model/backend identity, simulation time, and relevant residual or domain condition. Unsupported physics must fail during validation/compilation where discoverable. Explicitly configured approximation policies record every substitution and its effect; defaults never silently switch contact law, precision, backend or geometry authority.

Model compilation is transactional. A step commits state and advances time only after acceptance. Rejected trials, failed steps and cancellation retain the last accepted state, including warm-start, random and controller state. Multi-step runs may expose their already accepted prefix with an explicit terminal failure and last accepted time. Resource exhaustion must not return a truncated successful result.

### 2.3 Evidence policy

Each row's acceptance cell defines a falsifiable scenario. Before implementing that row, its fixture must specify input envelope, units/scales, interval, expected result/oracle, norm, tolerances and failure observations. Each requirement needs at least a successful in-domain case and a case that violates its input, capability, resource or convergence contract. Add boundary, concurrency, cancellation and lifecycle cases where applicable.

Numerical assertions use a dimensional absolute tolerance plus a relative term: `error <= absoluteTolerance + relativeTolerance * referenceScale`. Angle, length, speed, force, energy, position-constraint and velocity-constraint tolerances are separate. Near-zero quantities need physical reference scales, not division by zero. Defaults must derive from precision, model scale and convergence studies. A fixture owner freezes tolerances before evaluating a candidate; changing tolerances requires a new rationale and review, not merely obtaining a pass.

Evidence classes:

| Evidence ID | Obligation |
|---|---|
| EV-A | Analytic or manufactured solutions with independently derived expectations; time/mesh refinement when approximate. |
| EV-I | Conservation, virtual work, reciprocity, frame/unit invariance, dissipation and constraint residual checks appropriate to the model. |
| EV-R | Differential comparison with a pinned independent implementation using matched equations and settings; mismatches investigated, not voted away. |
| EV-F | Invalid, missing, singular, unsupported and non-converged cases exercise the actual production path and state preservation. |
| EV-L | Owner lifetime, snapshot validity, cancellation, shutdown, race and callback reentry behavior. |
| EV-P | Compile, link and runtime evidence for an exact toolchain/SDK/target/backend; unavailable runtime remains unverified. |
| EV-B | Reproducible workload envelope, hardware, warmup, repetitions, allocation/copy counts, memory and latency/throughput distributions. |

Every numerical family requires EV-A or EV-R plus relevant EV-I and EV-F. Lifecycle/performance/platform claims additionally require EV-L/EV-B/EV-P. A matching upstream simulation without matched model assumptions is not a numerical oracle.

## 3. Detailed requirements

The owner is a logical responsibility pending child design, not an existing SwiftPM module. All rows: `planned`. Source tags refer to [SOURCES.md](SOURCES.md); they indicate feature-area provenance, not that an upstream implements our exact contract.

### 3.1 MD — Mechanical model and compilation

Owner: model compiler. References: SB-API, MJ-MODEL, DK-PLANT. First delivery gate: G0.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| MD-001 | Stable IDs distinguish body instances, frames, joints, colliders, materials, loads, actuators and sensors. Repeated CAD occurrences remain distinct. | Duplicate or dangling IDs. | Reuse one part in multiple instances; remove referenced entities and verify diagnostics. |
| MD-002 | Explicit world/body/joint/sensor frames and directional transforms; spatial velocity and wrench conversion preserve physical meaning. | Invalid rotation, undefined frame. | Compose/invert frames and check wrench-power invariance. |
| MD-003 | SI storage with dimensional conversion at input/output boundaries, including angular quantities and gear/rack ratios. | Unit mismatch, overflow, nonfinite value. | Equivalent mixed-unit mechanisms produce equivalent SI results. |
| MD-004 | Compile topology, state layout, sparsity, dependencies and capabilities into an immutable model shared by independent states. | Invalid graph or unsupported feature combination. | Shared compiled model, independent rollouts, deterministic compilation diagnostics. |
| MD-005 | Separate geometric shape, display geometry, collision geometry and inertial properties with provenance and approximation metadata. | Missing required physical representation. | Change only display mesh and verify unchanged mechanics. |
| MD-006 | Validate axes, parameters, inertia, joint connections, force-law domains and constraint consistency before execution where decidable. | Structured errors identifying offending records. | A catalog of invalid models fails without a partial compiled model. |
| MD-007 | Parameter edits invalidate dependent caches; topology edits produce a new model revision and an explicit state migration policy. | Stale state or undefined migration. | Change joint topology and reject old state; migrate a documented compatible parameter edit. |
| MD-008 | Query model counts, DOF, constraint rank estimates, graph, state layout, selected equations and capability requirements. | Queries on invalid compiled state. | Compare report against independently counted tree and closed-loop fixtures. |

### 3.2 RB — Rigid bodies and inertia

Owner: rigid mechanics. References: CH-CORE, SB-CORE, RP-JOINT. First gate: G0/G1.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| RB-001 | Dynamic, static and prescribed-kinematic bodies in 2D/3D have explicit force, motion and reaction semantics. | Conflicting mode/actuation configuration. | Same contact against static, moving kinematic and dynamic obstacles. |
| RB-002 | Dynamic body mass is positive; inertia is symmetric, physically realizable and positive on admitted rotational DOF. | Invalid mass, eigenvalues or principal-moment inequalities. | Valid rotated inertias pass; nonphysical tensors fail. |
| RB-003 | Center-of-mass offsets and inertia changes of frame use parallel-axis and rotation laws. | Unsupported affine/non-rigid transform. | Composite masses and rotated off-center body match analytic tensors. |
| RB-004 | Analytic primitive and compound mass properties use declared density and prevent overlap double counting unless explicitly modeled. | Invalid density or ambiguous composition. | Box, sphere, cylinder and separated composite against analytic values. |
| RB-005 | Orientation integration uses a manifold representation; quaternion normalization and sign handling do not introduce spurious motion. | Invalid orientation or unrecoverable drift. | Free spinning asymmetric body; sign-equivalent orientations match. |
| RB-006 | Floating bases and fixed roots use explicit generalized-coordinate layouts without assuming q-count equals velocity-count. | Invalid base state/layout. | Floating robot transforms and velocities round-trip correctly. |
| RB-007 | Sleeping/waking is selectable, bounded by declared energy/velocity criteria, and wakes connected mechanisms on relevant changes. | Unsupported sleeping with selected formulation. | Resting stack wakes on impact, actuator command and topology change. |
| RB-008 | Body-local/world forces, impulses and angular impulses update momentum with the correct application-point moment. | Missing body, invalid point or impulse. | Off-center impulse matches analytic linear/angular momentum. |

### 3.3 JT — Joints and articulations

Owner: constraint modeling. References: CH-CORE, SB-API, RP-JOINT. First gate: G1.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| JT-001 | Fixed, revolute and prismatic joints define anchors, axes, permitted DOF and signed coordinates. | Degenerate axes or inconsistent anchors. | Free-axis motion and blocked-axis reaction tests for each joint. |
| JT-002 | Spherical, universal, cylindrical and planar joints support their intrinsic configuration manifolds and singularity diagnostics. | Invalid geometry or chart singularity. | Independent DOF counts and constraint residuals through large rotations. |
| JT-003 | Screw/helical joints couple translation and rotation with signed, dimensioned pitch. | Invalid pitch or unsupported limit combination. | Displacement per revolution and power consistency. |
| JT-004 | Generic joint locks/permits individual relative translation/rotation directions with a documented frame convention. | Overconstrained or ill-defined rotation chart. | Reconstruct standard joints and compare their trajectories/reactions. |
| JT-005 | Position/speed limits include unilateral activation, restitution/compliance choice and separate angular wrap policy. | Invalid limit interval or material parameters. | Approach limits from both sides; verify reaction and impact behavior. |
| JT-006 | Joint friction, stiffness and damping are explicit laws; locked, passive and actuated directions remain distinguishable. | Conflicting actuation or invalid law domain. | Damped hinge decay and static/kinetic joint-friction transitions. |
| JT-007 | Joint reaction force/torque reports frame, application point, sign and temporal interpretation, including impulse/step distinctions. | Reaction unavailable for chosen representation. | Pendulum support reaction and action/reaction balance. |
| JT-008 | Breakable/releasable joints use force/impulse criteria and explicit accepted-time topology transitions. | Undefined break metric or migration. | Threshold crossing separates bodies once; checkpoint/replay preserves event. |

### 3.4 CN — General constraints and assembly

Owner: constraint modeling/solving. References: CH-CORE, SB-CON, MJ-COMP. First gate: G1.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| CN-001 | Holonomic constraints expose g, Jacobian and time derivatives; explicit-time motion is distinguished from autonomous constraints. | Inconsistent derivative dimensions or invalid callback. | Differentiate analytic time-dependent loop constraint independently. |
| CN-002 | Nonholonomic velocity constraints state integrability assumptions and supply consistent acceleration-level terms. | Incompatible formulation or unavailable derivatives. | Rolling-without-slip benchmark preserves velocity residual. |
| CN-003 | General coordinate and speed coupling supports linear and differentiable nonlinear relations across permitted joint coordinates. | Cyclic inconsistency or singular coupling. | Coupled slider/rotor polynomial fixture and invalid relation. |
| CN-004 | Closed loops, multiple roots and mixed articulated/maximal-coordinate subassemblies retain all constraints. | Unsupported mixed graph or inconsistent closure. | Four-bar and parallel mechanism with independently checked closure. |
| CN-005 | Redundancy/rank deficiency reports rank, implicated constraints and reaction nonuniqueness; selected rank-handling policy is explicit. | Inconsistency or ambiguity forbidden by policy. | Duplicate consistent rows versus contradictory rows; no invented unique reaction. |
| CN-006 | Initial assembly solves admissible positions and projects admissible velocities under documented weighting and tolerances. | Infeasible assembly or nonconvergence. | Perturbed closed-loop model assembles; impossible dimensions fail. |
| CN-007 | Drift control offers projection/stabilization with parameters, correction size and introduced work reported. | Excess correction or incompatible settings. | Long-run pendulum/loop residual and energy correction measurement. |
| CN-008 | Constraint enable/disable and compliance changes occur at accepted boundaries with explicit impulse/state reconciliation. | Unsatisfiable transition. | Engage a lock on a moving shaft and account for momentum/energy change. |

### 3.5 KI — Kinematics and geometry of motion

Owner: kinematics. References: SB-API, DK-IK, CH-CORE. First gate: G1.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| KI-001 | Forward kinematics computes body/frame/point poses for articulated and assembled loop configurations. | Unassembled or incompatible state. | Serial chain and closed four-bar against analytic poses. |
| KI-002 | Spatial and point Jacobians state coordinate convention, reference frame and q/v mapping. | Missing frame or incompatible chart. | Independent directional derivatives and virtual-work identity. |
| KI-003 | Velocities, accelerations and Jacobian bias terms include moving frames and explicit-time constraints. | Missing derivative data. | Slider-crank analytic velocity/acceleration over a full revolution. |
| KI-004 | Position-level inverse kinematics accepts pose, point, orientation, joint-bound and loop constraints with initial guess/branch policy. | Infeasible, singular or nonconverged solution. | Reachable target meets all constraints; unreachable target reports residuals. |
| KI-005 | Differential IK supports velocity tasks, damped singularity treatment and explicit priority/weight semantics. | Infeasible task or unsupported priority combination. | Redundant arm tracks while respecting limits; singular case diagnosed. |
| KI-006 | Prescribed trajectories supply position, velocity and acceleration with consistent interpolation and discontinuity events. | Inconsistent derivatives or unhandled discontinuity. | Periodic cam input and piecewise trajectory with verified derivatives. |
| KI-007 | Distance/path/surface-following constraints require explicit geometry and parameterization domains. | Invalid parameter range or unavailable geometry query. | Follower tracks curve/surface; boundary exits fail or emit configured event. |
| KI-008 | Kinematic solving returns residuals, branch selection and achieved task values without fabricating dynamic forces. | Request for unsupported force inference. | Multiple IK branches and underdetermined force query are distinguished. |

### 3.6 DY — Forward, inverse and mixed dynamics

Owner: rigid mechanics. References: SB-CORE, DK-PLANT, MJ-COMP. First gate: G1.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| DY-001 | Forward dynamics includes gravity, Coriolis/centrifugal terms, inertial coupling, external/generalized forces and joint constraints. | Invalid inertia or unsolved system. | Pendulum, free body and driven two-link arm against analytic/reference results. |
| DY-002 | Inverse dynamics returns required generalized forces for admissible prescribed acceleration and stated contact assumptions. | Infeasible acceleration or ambiguous reactions. | Inverse-to-forward round trip; wall contact underdetermination reported. |
| DY-003 | Mixed dynamics solves prescribed accelerations and unknown accelerations/forces with explicit known/unknown partitions. | Conflicting or singular partition. | Partially driven chain matches independently solved block system. |
| DY-004 | Mass matrix, inverse-mass products and bias/gravity terms are queryable without advancing simulation state. | Stale caches or invalid state. | Symmetry/positivity and query-versus-step consistency. |
| DY-005 | Articulated-tree dynamics uses recursive algorithms; general constrained systems use declared sparse formulations. | Unsupported topology or factorization failure. | Tree oracle comparison and measured scaling with fixed workload structure. |
| DY-006 | Impacts solve velocity jumps with the selected restitution/friction/contact law and separate impulse from continuous force. | Inconsistent impact constraints or unsolved impulses. | Analytic collision momentum and restitution; simultaneous-impact reference fixture. |
| DY-007 | Generalized-force to body-wrench mapping conserves power and distinguishes actuator, applied, constraint and contact contributions. | Nonunique decomposition or unavailable output. | Virtual work and complete force-budget reconciliation. |
| DY-008 | Energy, momentum, work and dissipation are queryable with contributions and reference-frame conventions. | Unsupported energy for custom/nonconservative law. | Conservative orbit/pendulum and damped system energy balance. |

### 3.7 ST — Static, equilibrium and modal analysis

Owner: analysis. References: CH-CORE, DK-PLAN, SB-CORE. First gate: G1/G3.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| ST-001 | Nonlinear static equilibrium solves load/constraint balance with explicit contact assumptions and initial branch. | No equilibrium or nonconvergence. | Hanging load and spring equilibrium against analytic values. |
| ST-002 | Quasi-static continuation traces load/displacement changes and exposes branch, instability and hysteresis assumptions. | Limit-point/branch failure. | Nonlinear spring continuation and loading/unloading law fixture. |
| ST-003 | Constraint/contact reactions in statics expose underdetermination and the selected resolution policy. | Nonunique reaction forbidden by policy. | Over-supported beam reports ambiguity rather than invented certainty. |
| ST-004 | Linearize smooth admissible operating points into state/input/output derivatives with constraint reduction stated. | Nonsmooth point or singular reduction. | Small-angle pendulum and constrained small perturbations. |
| ST-005 | Modal analysis solves admitted rigid/flexible eigenproblems with normalization, mode classification and boundary conditions. | Ill-posed mass/stiffness pencil. | Beam frequencies and expected rigid-body zero modes. |
| ST-006 | Damped modes/frequency response report excitation, output, phase, units and linearization validity. | Invalid frequency or incompatible nonlinear request. | Analytic damped oscillator transfer response. |
| ST-007 | Linear/nonlinear buckling analyses publish geometric/material assumptions and distinguish instability from solver failure. | Unsupported element/material or failed continuation. | Euler column and independently validated nonlinear buckling case. |
| ST-008 | Load sweeps report complete parameter/result provenance and explicit per-case failures. | Failed case or invalid branch reuse. | Mixed feasible/infeasible sweep retains only accepted results with statuses. |

### 3.8 TR — Gears, shafts and transmission mechanisms

Owner: transmissions. References: CH-GEAR, CH-CORE, BT-GEAR, MJ-COMP. First gate: G1; geometric contact at G2/G3.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| TR-001 | Ideal external/internal spur gears enforce signed tooth-count ratio, phase and shaft-frame convention. | Invalid counts, axes or conflicting phase. | External 20:40 gears rotate oppositely at half speed; internal pair matches sign convention. |
| TR-002 | Bevel/helical ideal transmissions state shaft intersection/offset, handedness and axial/radial reaction assumptions. | Incompatible geometry or unsupported reaction model. | Right-angle bevel and opposite-hand helical fixtures with frame/reaction checks. |
| TR-003 | Rack/pinion converts signed angular motion to translation using dimensioned pitch radius and phase. | Invalid radius or rack alignment. | Travel per revolution and force/torque power identity. |
| TR-004 | Worm transmissions distinguish ideal ratio coupling from friction-dependent backdrive/self-locking models. | Missing friction model for self-locking claim. | Forward/reverse drive; configured self-locking validated against its constitutive model. |
| TR-005 | Gear trains support idlers, compound shafts, planetary carrier/sun/ring relationships and closed transmission loops. | Inconsistent loop ratios or locked DOF. | Willis relationship and branched gear-train speed/torque balance. |
| TR-006 | Belt, toothed belt, pulley and chain abstractions state no-slip, stretch, wrap and discrete-link fidelity levels. | Incompatible belt length/tension or missing geometry. | Pulley ratio, tension work and slack/stretch behavior at selected level. |
| TR-007 | One-dimensional shafts retain inertia, torque, torsional spring/damper and explicit rigid-body attachment mapping. | Invalid shaft inertia or incompatible axis. | Torsional oscillator and shaft/body torque reciprocity. |
| TR-008 | Differential/reducer/transmission networks expose port speeds/torques and preserve ideal power before modeled losses. | Conflicting port conditions. | Differential with unequal output loads and power budget. |
| TR-009 | Clutch, brake, freewheel and ratchet use explicit stick/slip/engagement state and unilateral drive semantics. | Invalid state transition or nonconvergence. | Engage under relative speed; verify impulse, heat/loss and one-way behavior. |
| TR-010 | Backlash, compliance and efficiency are optional explicit transmission laws with dimensions and direction-dependent loss. | Invalid clearance/efficiency or incompatible laws. | Torque reversal crosses backlash; dissipated energy stays nonnegative. |
| TR-011 | Cam/follower, slider-crank and linkage transmissions support explicit profile/closure geometry and contact versus ideal constraint selection. | Impossible closure or profile query failure. | Cam lift and slider-crank dead-center diagnostics. |
| TR-012 | Tooth-surface contact uses resolved collision geometry/material laws rather than substituting ideal ratio constraints. | Insufficient tooth resolution or unsupported contact model. | Loaded tooth engagement, contact force and mesh/time refinement. |
| TR-013 | Gear diagnostics report ratio/phase error, transmitted torque, shaft/bearing reactions and model fidelity. | Requested quantity absent from selected fidelity. | Torque-driven gears against ratios and analytic bearing-load assumptions. |
| TR-014 | Multiple mechanisms combined with motors, springs, contact and flexible shafts preserve a consistent force/energy budget. | Incompatible coupled model or unsolved constraints. | Motor–gear–load integration with torsional compliance and torque reversal. |

### 3.9 FL — Passive forces and loads

Owner: force laws. References: CH-CORE, SB-CORE, MJ-COMP. First gate: G1.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| FL-001 | Uniform/time-varying gravity and declared spatial gravity fields apply forces consistently to rigid and flexible mass. | Invalid field or missing derivatives when required. | Ballistic body and distributed beam load match integrated gravity. |
| FL-002 | Translational/torsional springs and dampers allow rest state, nonlinear curves and constitutive domains. | Invalid stiffness/damping or undefined curve range. | Analytic oscillator decay and nonlinear force–deflection energy. |
| FL-003 | Bushing laws support coupled six-axis stiffness/damping with explicit frames and passivity requirements. | Nonphysical matrices under passive policy. | Coupled deflection/wrench and nonnegative dissipated power. |
| FL-004 | Distributed force, pressure and follower loads map to equivalent generalized/nodal forces with geometric update rules. | Invalid support geometry or load field. | Integrated beam/pressure load and follower-load tangent check. |
| FL-005 | Drag, buoyancy and aerodynamic/hydrodynamic lumped loads state medium, reference speed and coefficient domains. | Missing medium properties or outside empirical range. | Terminal velocity, submerged volume and lift/drag direction checks. |
| FL-006 | Tendon/cable routing supports length, Jacobian, elastic/passive force, wrapping and pulley branches. | Invalid wrap geometry or discontinuous branch ambiguity. | Cable length derivative and virtual-work torque across routed path. |
| FL-007 | Custom force laws use bounded evaluation, explicit state/derivatives and failure propagation; callbacks cannot mutate the active state. | Callback failure, invalid output or reentry. | Failing custom law rolls back step; declared derivative matches reference. |
| FL-008 | Force contribution reports separate conservative, dissipative, active and externally prescribed work without claiming passivity for arbitrary laws. | Missing energy law for requested conservative claim. | Independent force/work decomposition over complete motion. |

### 3.10 AC — Motors and actuators

Owner: actuation. References: CH-CORE, MJ-MODEL, RP-JOINT. First gate: G1.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| AC-001 | Torque/force, velocity and position drives distinguish effort actuation from prescribed motion constraints. | Conflicting drive modes or inaccessible DOF. | Compare free acceleration, speed servo and prescribed-speed reaction. |
| AC-002 | Linear/rotary servos expose control gain, effort/speed limits, saturation, deadband and anti-windup policy. | Invalid gains or inconsistent limits. | Saturation/recovery and disturbance response with work accounting. |
| AC-003 | Actuator activation/filter/delay/internal state advances with simulation time and checkpoint semantics. | Invalid delay or incompatible step/event scheme. | Step response and restored internal-state continuation. |
| AC-004 | Motor/electromechanical lumped models include selected electrical dynamics, back-EMF, torque constant and losses. | Missing parameters or outside parameter domain. | Analytic unloaded motor and electrical/mechanical power balance. |
| AC-005 | Hydraulic/pneumatic lumped actuators state compressibility, pressure/flow/volume laws and mechanical port coupling. | Invalid pressure/volume or unsupported regime. | Cylinder load response and fluid/mechanical energy accounting. |
| AC-006 | Muscle-like actuators provide explicit activation and force–length–velocity models with bounded physiological parameter domains. | Invalid material/activation domain. | Published-equation fixture and tendon transmission work consistency. |
| AC-007 | Actuator transmissions map joint, tendon, body and multi-DOF ports with consistent moment arms and mechanical advantage. | Singular or undefined transmission. | Port virtual work and force mapping across moving geometry. |
| AC-008 | Actuator outputs include requested/applied effort, clipping, internal state, power and energy/loss components. | Unsupported observable or failed actuator evaluation. | Full drive/load energy budget and explicit saturation reporting. |

### 3.11 CL — Collision geometry and scene queries

Owner: collision detection. References: BT-CORE, RP-COLL, DK-PLAN. First gate: G2.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| CL-001 | Sphere, box, capsule, cylinder, cone, half-space and convex hull proxies define size/margin/support conventions. | Degenerate shape or unsupported pair. | Pairwise analytic separation/penetration and transform invariance. |
| CL-002 | Compound, concave triangle mesh and heightfield support declare static/dynamic/deforming restrictions. | Invalid mesh or forbidden dynamic concavity. | Concave cavity, seam crossing and supported moving-mesh cases. |
| CL-003 | Broad phase conservatively finds candidate pairs with update/refit/invalidation rules and capacity limits. | Capacity exhaustion or stale geometry. | Compare with exhaustive pairs including fast motion and large scale disparity. |
| CL-004 | Narrow phase returns framed witness points, normal, signed separation, feature IDs and degeneracy diagnostics. | Undefined normal or failed geometric iteration. | Primitive analytic and convex reference fixtures; coincident configurations. |
| CL-005 | Persistent contact manifolds merge/prune using explicit tolerances and revision-aware feature identities. | Invalidated manifold or exhausted capacity. | Stable box contact through sliding, mesh seams and geometry edits. |
| CL-006 | Continuous collision detection handles admitted translation/rotation with time-of-impact bounds and explicit iteration budgets. | Unsupported sweep or unconverged TOI. | High-speed thin-wall and rotating-blade fixtures avoid tunneling within bounds. |
| CL-007 | Collision filtering supports layers, masks, joint exclusions, self-collision and user policy with deterministic precedence. | Conflicting or invalid filter references. | Exhaustive expected pair set and connected/self-collision cases. |
| CL-008 | Ray/shape cast, overlap, closest-point and signed-distance queries specify inside/edge/tie behavior and output ordering. | Unsupported query geometry or invalid ray. | Analytic hits, grazing boundaries and deterministic ties. |
| CL-009 | Triggers/sensors emit intersection events without generating mechanical response unless separately configured. | Invalid event lifecycle or unsupported pair. | Pass-through trigger generates ordered enter/exit events and zero impulse. |
| CL-010 | Collision representation records approximation error, source revision and contact-relevant resolution; display LOD is independent. | Unbounded approximation or incompatible requested fidelity. | Refined proxy distance/contact convergence and unchanged result after display LOD edit. |

### 3.12 CT — Contact, friction and impact laws

Owner: contact mechanics. References: CH-CORE, SB-CORE, MJ-COMP, DK-CON. First gate: G2; distributed contact at G3.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| CT-001 | Explicitly choose nonsmooth rigid, compliant penalty or regularized optimization-based contact with published equations. | Unsupported model/backend pairing. | Matched-model benchmarks and explicit rejection of incompatible combinations. |
| CT-002 | Unilateral normal contact enforces its stated complementarity/compliance law and reports residual/penetration measures. | Inconsistent contact or acceptance failure. | Resting body and impact with model-specific residual checks. |
| CT-003 | Coulomb stick/slip with separate static/dynamic parameters exposes cone representation and transition regularization. | Invalid friction or unresolved transition. | Inclined-plane onset, steady sliding and friction-cone bounds. |
| CT-004 | Anisotropic friction declares contact tangent frame and directional coefficients, preserving frame transformations. | Invalid tangent basis or constitutive parameters. | Sliding along/diagonal to anisotropy axes under rotated scene. |
| CT-005 | Rolling/spinning resistance states torque law and effective radius/units rather than conflating it with tangential friction. | Missing law parameters or invalid radius. | Rolling sphere and spinning contact dissipation. |
| CT-006 | Restitution and impact threshold policy separate impact loss from compliant damping and prevent unintended double counting. | Incompatible restitution/damping selection. | Drop height and impact energy across speed regimes. |
| CT-007 | Hertz/Hunt–Crossley and linear compliant laws define penetration, damping and material validity domains. | Invalid modulus, geometry or negative-force policy violation. | Sphere contact force curve and damped impact refinement. |
| CT-008 | Distributed/hydroelastic contact computes patch pressure and integrated wrench with explicit compliant/rigid representation requirements. | Missing pressure field or unsupported material pairing. | Loaded contact patch, wrench integration and mesh convergence. |
| CT-009 | Adhesion/cohesion models expose tensile limits, separation work and finite interaction range. | Invalid cohesive law or unsupported pairing. | Pull-off force and complete separation energy. |
| CT-010 | Material-pair combination rules and overrides are explicit, ordered and recorded; geometry/material edits invalidate contact data. | Ambiguous pair rule or stale cache. | Swap body order, override material and verify predictable force change. |
| CT-011 | Contact outputs provide normal/tangent force or impulse, wrench, patch/feature IDs, active set and stick/slip state with time semantics. | Quantity unavailable at selected fidelity. | Compare resultant against body momentum and friction work. |
| CT-012 | Multi-contact stacks, grasping and gear-tooth contacts solve coupled reactions with convergence diagnostics and known nonuniqueness exposed. | Infeasible/ambiguous/nonconverged solve. | Stack stability, frictional grasp and loaded tooth benchmark with refinement. |

### 3.13 SO — Numerical solvers and conditioning

Owner: numerical solving. References: CH-CORE, SB-CORE, MJ-COMP. First gate: G1/G2/G3.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| SO-001 | Dense and sparse linear solves expose factorization class, pivoting, ordering and failure/rank diagnostics. | Singular, indefinite or unsupported matrix class. | Manufactured SPD, indefinite saddle-point and singular systems. |
| SO-002 | Articulated recursive solves and constraint Schur-complement operations preserve documented sparsity and coordinate semantics. | Invalid graph or failed reduced solve. | Agreement with independent dense assembly on small mechanisms. |
| SO-003 | Nonlinear Newton/trust-region/line-search solving reports residuals, step acceptance and derivative requirements. | Nonconvergence, invalid derivative or singular tangent. | Manufactured nonlinear equilibrium with difficult initial guess and failure case. |
| SO-004 | Projected iterative, complementarity and convex contact solvers state supported cone/law, stopping measure and feasibility checks. | Unsupported law or residual above tolerance. | Frictionless LCP and frictional cone reference problems. |
| SO-005 | Warm-start and preconditioner caches are state-owned, revision-aware and semantically optional. | Stale cache or invalid restart. | Cold/warm solves meet same tolerance; replay preserves continuation state. |
| SO-006 | Scaling and regularization are explicit, dimensionally meaningful and report perturbation magnitude/model effect. | Required perturbation exceeds allowed policy. | Mixed mass/length scales and rank-deficient fixture with reported changes. |
| SO-007 | Iteration, memory, fill-in and work budgets belong to the configured solve; exhaustion is a typed failure. | ResourceLimit with last residual and phase. | Force every budget boundary without successful truncation. |
| SO-008 | Independent residual recomputation checks solution acceptance against original equations, not only internal convergence flags. | Internal/external residual disagreement. | Deliberately premature solver termination is rejected. |
| SO-009 | Diagnostics include iterations, conditioning estimates, active-set changes, constraint rank and relevant feasibility/optimality measures. | Unavailable metric explicitly identified. | Known ill-conditioned fixture has traceable diagnosis. |
| SO-010 | Precision/backend selection declares scalar type and supported algorithms; lower precision never silently replaces requested precision. | Unsupported precision or backend capability. | Float64 baseline and explicitly selected Float32 differential error study. |

### 3.14 TI — Time integration and hybrid events

Owner: simulation stepping. References: SB-CORE, CH-CORE, MJ-RUN. First gate: G1; contact/flexible at G2/G3.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| TI-001 | Fixed-step semi-implicit/symplectic Euler and explicit higher-order Runge–Kutta publish order/stability and model compatibility. | Invalid step or incompatible stiff/nonsmooth request. | Smooth analytic oscillator convergence and long-term energy envelope. |
| TI-002 | Adaptive embedded integration uses dimensional error norms, accepted/rejected-step reporting and bounded step control. | Minimum-step exhaustion or failed error target. | Analytic varying-timescale motion meets tolerance with observed order. |
| TI-003 | Implicit Euler and generalized-alpha/HHT-style structural integration specify nonlinear solve and numerical dissipation parameters. | Invalid parameters or nonlinear solve failure. | Stiff spring and flexible beam convergence/damping study. |
| TI-004 | Constraint-aware DAE integration states index treatment, projection/stabilization and q/v consistency rules. | Inconsistent initial state or unsupported DAE formulation. | Constrained pendulum and closed-loop residual over long runs. |
| TI-005 | Nonsmooth contact time stepping and impact-event integration state impulse equations and within-step event policy. | Unresolved impact or event budget exhaustion. | Bouncing body and contact stack with momentum/residual checks. |
| TI-006 | Root-located events have direction, tolerance, ordering, simultaneous-event and chatter handling policies. | Ambiguous transition or excessive event cascade. | Multiple impacts/limits at equal times with repeatable ordering. |
| TI-007 | Dense output/interpolation respects the manifold and event boundaries and does not imply a new accepted solver state. | Interpolation across unsupported discontinuity. | Intermediate smooth trajectory values and boundary-aware impact output. |
| TI-008 | Multi-rate/substep integration declares coupling/exchange order, force/impulse accumulation and synchronization times. | Unsupported rate pairing or coupling convergence failure. | Fast flexible shaft/slow controller with synchronization and energy checks. |
| TI-009 | Step/run/advance-to-time APIs distinguish accepted time, requested time, stop conditions and partial-prefix failures. | Overshoot policy violation or terminal failure. | Adaptive target-time run, stop event, cancelled run and restored prefix. |
| TI-010 | Rejected trials roll back every stateful subsystem and side effect; event/sensor publication occurs after acceptance. | Nontransactional custom subsystem. | Force rejection after actuation/random update and compare replay bitwise where promised. |

### 3.15 FX — Flexible and deformable mechanics

Owner: flexible mechanics. References: CH-FEA, MJ-OV, BT-CORE. First gate: G3.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| FX-001 | Mass–spring, cable and rope models state stretch/bend/twist capabilities, rest geometry and discretization assumptions. | Invalid rest length or unsupported constitutive mode. | Hanging cable, axial vibration and refinement against analytic/reference model. |
| FX-002 | Beam elements cover Euler–Bernoulli and shear-deformable behavior, torsion and declared finite-rotation formulations. | Unsupported slenderness/material regime or singular element. | Cantilever, torsion and large-rotation objective response. |
| FX-003 | Shell/membrane/cloth models state bending, thickness, shear and large-deformation assumptions. | Invalid thickness or element geometry. | Plate bending, membrane stretch and drape refinement. |
| FX-004 | Tetrahedral/hexahedral solid elements expose interpolation order, quadrature and locking/hourglass policies. | Inverted/degenerate cells or unstable element mode. | Patch tests, volumetric strain and mesh-converged solid deformation. |
| FX-005 | Linear elasticity, nonlinear hyperelasticity and bounded elastoplastic models specify stress/strain measures and parameter domains. | Invalid material, constitutive nonconvergence or outside calibrated domain. | Uniaxial/shear cycles, elastic recovery and plastic dissipation. |
| FX-006 | Geometric nonlinearity and corotational/ANCF-style finite-motion choices publish objectivity and tangent consistency. | Unsupported element/formulation pairing. | Superposed rigid rotation adds no strain; tangent directional check. |
| FX-007 | Consistent/lumped mass, stiffness and damping matrices have declared conservation and definiteness properties. | Invalid mass/damping model. | Modal frequencies, rigid-body modes and damping energy balance. |
| FX-008 | Rigid–flexible, flexible–flexible and boundary attachments transfer forces/moments consistently with selected attachment DOF. | Overconstrained or undefined attachment. | Flexible shaft attached to gear hubs with interface power balance. |
| FX-009 | Deforming collision, self-contact and friction update geometry and contact forces while retaining material coordinates. | Unsupported deforming pair or exhausted contact budget. | Folded cloth/cable self-contact and deforming-body impact. |
| FX-010 | Stress, strain, displacement, internal force and energy outputs identify location, measure, projection and averaging policy. | Unsupported stress measure or invalid query location. | Beam/solid analytic field and resultant integration. |
| FX-011 | Reduced/modal flexible models state basis, retained modes, interface treatment and validity/error envelope. | Outside reduced-model envelope or incompatible boundary edit. | Full/reduced frequency and transient comparison across retained modes. |
| FX-012 | Mesh import/validation and discretization refinement preserve boundary/material/source assignments and diagnose element quality. | Invalid connectivity, inverted cells or missing assignment. | Refinement preserves loads/constraints and converges displacement/stress quantities. |

### 3.16 CO — Control and system composition

Owner: control systems. References: DK-PLAN, DK-PLANT, MJ-OV. First gate: G4.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| CO-001 | Continuous/discrete systems compose through dimensioned ports, explicit sample periods and declared direct feedthrough. | Incompatible ports or unresolved algebraic loop. | Controller–plant diagram versus independently integrated system. |
| CO-002 | PID, joint servo and computed-torque controllers state gains, saturation, derivative/filter and anti-windup rules. | Invalid gain or unsupported plant model. | Tracking/disturbance tests with actuator bounds and energy accounting. |
| CO-003 | State-space/LQR control requires validated linearization and Riccati solution diagnostics. | Unstabilizable or numerically failed design. | Analytic linear system and nonlinear plant near operating point. |
| CO-004 | MPC solves bounded horizon problems with explicit costs, constraints, terminal assumptions and failure handling policy. | Infeasible/nonconverged problem; no implicit reuse of old command. | Feasible tracking and infeasible horizon with explicit caller-selected response. |
| CO-005 | Operational/task-space control handles Jacobians, singularities, priorities and force/motion task compatibility. | Singular or conflicting task. | End-effector tracking and constrained force control at singular configurations. |
| CO-006 | State estimators support declared linear/nonlinear filter models, covariance and observation timing. | Invalid covariance, unobservable setup or failed innovation solve. | Synthetic known-state estimation and delayed/missing observations. |
| CO-007 | Controller state, clock, sampled inputs and randomness are included in rollback/checkpoint and deterministic replay scope. | Uncheckpointable stateful callback. | Same saved plant/controller state reproduces commands and motion. |
| CO-008 | Co-simulation/external control ports declare timestamp, hold/interpolation, delay, ordering and synchronization behavior. | Stale/out-of-order input or missed synchronization contract. | Delayed/out-of-order command fixture and time-consistent coupled run. |

### 3.17 OP — Differentiation, optimization and planning

Owner: differentiation/optimization. References: DK-PLAN, DK-IK, DK-TRAJ, MJ-COMP. First gate: G4.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| OP-001 | Derivatives of smooth kinematics/dynamics expose Jacobian, directional-product and parameter-sensitivity operations with domain metadata. | DerivativeUnavailable at unsupported/nonsmooth points. | Analytic derivatives and independent directional differences over smooth fixtures. |
| OP-002 | Automatic/analytic differentiation covers admitted scalar operations and custom subsystem derivative contracts without hidden finite-difference substitution. | Unsupported differentiated operation. | Composition derivatives and explicit failure for derivative-free callback. |
| OP-003 | Contact/impact differentiation declares fixed active-set, smoothing or generalized derivative semantics and validity boundaries. | Active-set ambiguity or unsupported derivative model. | Smooth contact fixture and impact boundary explicitly distinguished. |
| OP-004 | Optimization accepts costs, equalities, inequalities, bounds and sparse derivatives; reports feasibility, optimality and terminal status. | Invalid problem, infeasible, unbounded or nonconverged. | Known LP/QP/nonlinear optima plus each terminal failure class. |
| OP-005 | Constrained IK/pose optimization combines joint, collision, orientation and task constraints with branch and initialization metadata. | Infeasible or nonconverged pose. | Reachable collision-free target and impossible target with witnesses. |
| OP-006 | Trajectory optimization supports shooting and direct transcription/collocation with dynamics, bounds, costs and initial/final constraints. | Failed dynamics/derivative or infeasible optimization. | Pendulum swing-up trajectory independently replayed and checked between knots. |
| OP-007 | Collision-aware path planning exposes collision query assumptions, clearance, termination budgets and path validation. | No path within budget or invalidated geometry. | Narrow-passage path and blocked scene; continuous segment verification. |
| OP-008 | Time parameterization enforces speed, acceleration and effort constraints under declared dynamics and interpolation. | Infeasible timing or unsatisfied inter-knot limits. | Robot path retiming independently sampled/replayed for all limits. |
| OP-009 | Parameter estimation/system identification reports bounds, objective, identifiable directions and uncertainty assumptions. | Unidentifiable or invalid observation model. | Recover known mass/damping from synthetic data; correlated parameters diagnosed. |
| OP-010 | Design/sensitivity optimization retains CAD/mechanics parameter provenance and refuses derivatives through topology changes unless explicitly defined. | Discontinuous topology or stale parameter mapping. | Smooth gear/shaft parameter study and topology-change rejection. |

### 3.18 SE — Sensors and observations

Owner: observations. References: MJ-OV, MJ-RUN, RP-COLL. First gate: G1/G2/G4 as applicable.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| SE-001 | Joint encoders, pose, speed and acceleration observations expose frame, units, sampling time and continuous/discrete semantics. | Unsupported observable or invalid frame. | Analytic rotating/accelerating mechanism observations. |
| SE-002 | Force/torque sensors include mounting transform, sign, gravity compensation policy and force-versus-impulse interpretation. | Missing reaction path or unavailable decomposition. | Static suspended mass and moving sensor frame. |
| SE-003 | IMU accelerometer/gyro observations distinguish specific force from world acceleration and include sensor offsets. | Missing acceleration or invalid sensor mounting. | Free fall, stationary support and off-center rotation. |
| SE-004 | Contact/tactile/range sensors report source contact/query fidelity, hit geometry and timestamp. | Unsupported sensor model or absent geometry capability. | Trigger/range/tactile outputs versus contact and analytic query fixtures. |
| SE-005 | Noise, bias, quantization, saturation, delay and dropout are explicitly configured and seeded. | Invalid statistics or delay/resource domain. | Seeded replay and independent statistical validation. |
| SE-006 | Sensor schedules align to accepted simulation time; interpolation/event treatment is explicit and rejected trials are not published. | Unsupported sampling/interpolation combination. | Adaptive-step run with fixed sensor period and rejected trials. |
| SE-007 | Observation buffers declare ordering, capacity, overflow and ownership; borrow lifetimes cannot escape valid storage. | Explicit overflow or invalid lease. | Slow consumer, shutdown and owner-release tests. |
| SE-008 | Observation sets support headless control/learning with explicit schema, bounds and revision compatibility. | Incompatible observation/action schema. | Batched rollout and invalid schema/version rejection. |

### 3.19 RT — Runtime, ownership and reproducibility

Owner: runtime. References: MJ-RUN, RP-DET; our ownership requirements. First gate: G0/G1, expanded with every gate.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| RT-001 | Immutable compiled model and uniquely owned mutable simulation state/workspace have revision-checked association. | Model/state mismatch or invalid owner access. | Share model across concurrent independent states without coupling. |
| RT-002 | Step ordering is serialized per state; short shared metadata access uses one consistent synchronization contract across targets. | Reentry or invalid concurrent mutation. | Concurrent step/query/shutdown and callback reentry tests. |
| RT-003 | Checkpoints include physical, actuator/controller, event, random, warm-start and integrator continuation state. | Missing state contributor or incompatible revision. | Save/restart continuation versus uninterrupted accepted trajectory. |
| RT-004 | Determinism tiers separate same-build replay, numerical cross-platform equivalence and explicitly qualified bitwise portability. | Requested determinism tier unsupported. | Seeded repeated runs and exact qualified target-pair comparison. |
| RT-005 | Independent worlds and batched rollouts avoid state leakage, publish seed derivation and bound task/workspace ownership. | Batch capacity or failed world reported explicitly. | Parallel batch versus sequential independent executions. |
| RT-006 | Cancellation reaches bounded solver/step safe points; shutdown finishes streams and releases each resource exactly once. | Cancelled/closed session with last accepted state. | Cancel inside solve, shutdown during observation and owner lifetime tests. |
| RT-007 | Steady-state stepping supports reserved workspace and borrowing views; allocation/copy budgets are measured per declared workload. | Capacity exhaustion, never unreported buffer growth under strict policy. | Instrument allocations/copies across long settled and changing-contact runs. |
| RT-008 | Profiling records compilation, collision, solving, integration and output costs with residuals, memory and workload identity. | Unavailable measurement explicitly marked. | Reproducible end-to-end benchmark isolates bottleneck and output overhead. |

### 3.20 CA — swift-CAD integration

Owner: CAD adapter. References: local CAD observations in SOURCES.md; our integration requirements. First gate: G1; contact/flexible/optimization at later gates.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| CA-001 | CAD integration depends on swift-CAD public products; mechanics computation without CAD input has no CAD dependency requirement. | Missing/incompatible CAD capability. | Build/run core without CAD; adapter integration with pinned CAD products. |
| CA-002 | Map CAD body definitions and repeated assembly occurrences to distinct mechanics instances, preserving placement and source revision. | Ambiguous occurrence mapping. | Two instances of one part move independently with traceable provenance. |
| CA-003 | CAD-derived mass properties combine explicit density/material with validated volume/centroid/inertia integration and documented error. | Missing full geometric moments or unbounded integration error. | Primitive/composite analytic moments and general BRep refinement with invalid-solid failures. |
| CA-004 | Exact geometric integration belongs to CAD geometric authority; mechanics owns density and inertia use. Approximate mesh integration requires explicit policy/provenance. | Required exact CAD query unavailable. | Exact-required path refuses absent capability; approved approximation carries bounds. |
| CA-005 | Derive collision proxies/FEM domains with deviation, resolution, orientation and source-face/body mappings. | Invalid mesh, unknown error or lost assignments. | Analytic CAD distances and refined contact/deformation with source attribution. |
| CA-006 | Joint/shaft frames and contact associations refer to stable CAD anchors with explicit resolution and invalidation rules. | Deleted/ambiguous anchor after CAD edit. | Edit source face and detect stale constraint rather than binding silently elsewhere. |
| CA-007 | Involute-gear shape parameters can populate proposed transmission inputs only after checking units, axes, phase and selected fidelity. | Shape lacking required mechanics data. | Two CAD gears explicitly bound to shafts; motion and load match TR contracts. |
| CA-008 | Simulation outputs map poses and force/stress/contact overlays to occurrence/source IDs without mutating CAD geometry. | Stale output/source revision. | Animated repeated parts and face-associated reactions retain authoritative geometry. |
| CA-009 | CAD edits rebuild affected model/proxies and require an explicit physical-state migration/reinitialization choice. | Invalidated geometry/state mapping. | Resize gear during paused simulation; require validated restart or compatible migration. |
| CA-010 | CAD support claims require a clean pinned remote dependency, exercised production adapter and success/failure evidence for each claimed capability. | Unverified dependency or unsupported query/format. | Resolve/build pinned graph and run geometry-to-motion integration; local-path overrides cannot certify release. |

### 3.21 IO — Persistence, formats and interoperability

Owner: exchange. References: MJ-MODEL, DK-MB, CH-CORE; our fidelity requirements. First gate: G0/G1; format breadth expanded at G4.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| IO-001 | Versioned native mechanics schema preserves units, graph, laws, parameters, IDs and provenance; unknown fields/features follow explicit policy. | IncompatibleData or unsupported required feature. | Round-trip all supported model families and reject incompatible versions. |
| IO-002 | Native checkpoints distinguish model compatibility from build/backend continuation compatibility and publish migration rules. | Incompatible checkpoint or missing required state. | Corrupt/truncated/revision-mismatched data rejected transactionally. |
| IO-003 | URDF import/export defines supported joints, inertials, geometry, transmissions and extension loss report. | Unsupported feature or prohibited lossy conversion. | Robot round-trip and invalid inertia/mimic/unit cases. |
| IO-004 | SDF import/export declares supported world, model, frame, joint, collision and sensor semantics per pinned format version. | Unsupported semantics or unresolved frame. | Nested-frame/world fixture preserves mechanics or reports losses. |
| IO-005 | MJCF import/export declares supported actuator, tendon, equality, material, sensor and solver semantics without pretending numerical equivalence. | Unsupported law or incompatible model choice. | Feature-rich model conversion with explicit semantic differences and rejection cases. |
| IO-006 | OpenUSD physics/scene interoperability preserves occurrence mapping and simulation attributes under a stated schema/version subset. | Unsupported schema, stale stage or lossy policy violation. | Assembly pose/joint/material round-trip with separate CAD geometry ownership. |
| IO-007 | Trajectory/force/diagnostic export includes schema, units, timestamps, reference frames, fidelity and terminal status. | Serialization/IO failure propagated. | Export/import independently reconstructs time/force meaning including failed run prefix. |
| IO-008 | Input parsing/asset resolution uses bounded sizes, explicit base paths, validation and transactional loading. | Missing asset, excessive data or invalid external reference. | Malformed/cyclic/oversized assets and interrupted load cannot create partial success. |

### 3.22 PF — Platforms, APIs and execution backends

Owner: platform/API integration. References: upstream API inventories; our Swift portability requirements. First gate: G0, extended per feature gate.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| PF-001 | Native Swift Float64 CPU mechanics is the correctness baseline; interfaces are protocols with separate implementations and typed failures. | Missing baseline capability. | Public API drives real baseline mechanics success/failure fixtures. |
| PF-002 | Core is headless and independent of SwiftUI, rendering and application document state; display adapters consume accepted snapshots. | Unsupported display integration explicitly reported. | Same mechanism runs without a window and with visualization. |
| PF-003 | macOS and Linux CPU support use pinned toolchains/platform dependencies and execute declared required feature suites. | Unsupported target/backend combination. | Compile/link/runtime on both targets; no portability inference from one. |
| PF-004 | iOS-family Apple deployment declares supported product/capability set and SDK/destination requirements independently of macOS. | Unavailable SDK/backend capability. | Target-specific compile/link/runtime of each published feature claim. |
| PF-005 | WASM and Embedded WASM are distinct profiles with matching pinned toolchain/SDK, runtime and explicit feature manifests. | Unsupported runtime/API/capability. | Separate build/link/runtime evidence; browser/Node claims tested in their own environments. |
| PF-006 | Shared-state synchronization, Sendable and ownership contracts remain the same across native/WASM/Embedded; target changes stay in actual platform adapters. | Missing compatible synchronization backend. | Compiled declaration comparison and target-specific race/lifecycle evidence. |
| PF-007 | Accelerated GPU/parallel backends declare precision, supported physics, determinism and transfer/ownership rules; selection is explicit. | Unsupported capability, device failure or lost execution. | CPU differential fixtures and real device kernels with transfer/resource accounting. |
| PF-008 | C ABI and browser-facing interfaces expose safe handles, bounded buffers, ownership and typed status with no escaping Swift internals. | Invalid/stale handle, buffer or ABI version. | Independent caller exercises success, failure, release and concurrency cases. |
| PF-009 | External-engine adapters are identified interoperability/reference backends with explicit semantic mapping and dependency/license metadata. | Unsupported mapping or unavailable engine. | Same model comparison exposes equation differences; native support status remains separate. |
| PF-010 | Capability manifests enumerate feature IDs, backend/model combinations, precision, targets and evidence revisions rather than marketing-only support flags. | Unsupported request rejected before execution where possible. | Manifest claims exactly match exercised paths, including negative combinations. |

### 3.23 EX — Domain-specific engineering extensions

Owner: each domain extension with its own subordinate design. References: CH-VEH, CH-WIDE. First gate: G5. These are required target extensions, not implemented or omitted through an early release gate.

| ID | Required behavior and accepted domain | Specific failure | Acceptance evidence |
|---|---|---|---|
| EX-001 | Wheeled-vehicle assemblies compose steering, suspension, driveline, brakes and driver control from verified mechanics contracts. | Invalid subsystem composition or unsupported coupling. | Straight-line acceleration/braking and suspension load-transfer benchmarks. |
| EX-002 | Tire/road and deformable-terrain laws state empirical/calibrated scope, slip definitions, normal load and energy assumptions. | Outside calibrated domain or missing terrain data. | Tire force curves, rolling resistance and wheel/soil reference tests. |
| EX-003 | Tracked vehicles model track/link/contact or explicitly reduced tracks with terrain interaction and fidelity metadata. | Unsupported fidelity or failed track closure/contact. | Track circulation, traction and obstacle traversal against pinned reference. |
| EX-004 | Granular/discrete-element systems support particle size/material distributions, cohesive/frictional contact and rigid-boundary coupling. | Invalid particles or exhausted neighbor/contact capacity. | Two-particle collision, bulk settling and reproducible shear reference. |
| EX-005 | Particle/discretized-fluid interaction states equations, viscosity/compressibility assumptions, boundaries and stability criteria. | Invalid fluid state or unsupported regime. | Hydrostatic pressure, viscous flow and refinement/stability study. |
| EX-006 | Fluid–rigid/flexible coupling exchanges force/momentum with explicit coupling time and conservation/error diagnostics. | Interface inconsistency or coupling nonconvergence. | Floating rigid body and flexible immersed structure with force/energy balance. |
| EX-007 | Domain acceleration supports measured large-scale partitioning/GPU execution with explicit reproducibility and communication budgets. | Backend/capacity/communication failure. | Small CPU oracle plus scalable workload and actual accelerated execution. |
| EX-008 | Co-simulation between domain products specifies exchange variables, rollback capability, clocks and convergence policy. | Incompatible units/clocks or unrecoverable participant failure. | Coupled vehicle–terrain/fluid fixture with delay and participant failure injection. |

## 4. Delivery gates and dependency order

These gates are capability claims, not dates. Every listed family must be checked at the feature/model/target level. Mixed-gate families complete their foundational contracts first and remain partially planned until all their rows pass. Supporting rows in RT, IO, PF and CA apply wherever a gate uses their paths.

```mermaid
flowchart LR
  G0["G0: model and runtime foundation"] --> G1["G1: engineering mechanisms"]
  G1 --> G2["G2: collision and contact"]
  G2 --> G3["G3: flexible and distributed contact"]
  G3 --> G4["G4: control, optimization, exchange"]
  G4 --> G5["G5: coupled domain extensions"]
  G5 --> Full["Complete target: all requirements verified"]
```

| Gate | Required result | Evidence that must reject an incorrect implementation |
|---|---|---|
| G0 | Model compilation, units/frames, valid inertia, immutable model/state ownership, baseline platform and schema contracts. | Invalid-input corpus; frame/inertia analytic tests; state isolation; actual target compile/link/runtime. |
| G1 | Load-driven mechanisms, joints/loops, gears/shafts/motors, dynamics/statics, integration, basic sensors and real CAD adapter. | Analytic gears and oscillator; four-bar; inverse/forward consistency; bearing reactions; rollback/cancellation; CAD occurrence/mass/anchor failures. |
| G2 | Collision, CCD, nonsmooth/compliant contact, friction and associated event/sensor/runtime contracts. | TOI bounds; cone/complementarity residuals; inclined plane; stack and tooth-contact load; mesh/time refinement and capacity failures. |
| G3 | Flexible models, constitutive laws, distributed contact, rigid/flexible coupling and applicable modal/stability analysis. | Patch/objectivity tests; beam/solid convergence; constitutive dissipation; coupled interface energy; invalid/inverted meshes. |
| G4 | Control, differentiation, optimization/planning and declared interoperability products. | Derivative checks; infeasible/nonsmooth failures; independent trajectory replay; controller checkpoint; supported-format round-trip/loss reports. |
| G5 | Vehicle, granular, fluid and coupled extensions, including their accelerated/distributed execution claims. | Domain reference fixtures; mesh/time studies; coupling balances; participant failures; measured device/scale runs. |
| Complete target | Every row has native or explicitly allowed integration implementation, domain bounds, evidence and accurate manifest status. | Cross-family integration suite, full traceability audit and no planned/unverified required row. |

A gate may ship a clearly labeled subset only if its published capability manifest names exactly that subset; it must not claim the entire gate or complete target. Reclassifying a required row as optional requires a user-approved scope revision, not schedule pressure.

## 5. Required end-to-end proof scenarios

These scenario IDs group interacting requirements and do not replace their local tests. Before implementation, every scenario gets concrete scales, numerical tolerances, duration, resources and target/backend matrix under the evidence policy.

| Scenario ID | Cross-family production path | Required observations |
|---|---|---|
| INT-01 | CAD spur gears → occurrences → inertia/shafts → motor → ideal coupling → load → output | External/internal signs, ratio, phase, torque/power and bearing reactions; missing density/anchor/capability failures. |
| INT-02 | Planetary/differential + clutch/brake + flexible shaft + controller | Port power, torsional modes, engagement/reversal events, loss and saturation; no duplicate actuation/constraints. |
| INT-03 | Closed four-bar/slider-crank → assembly → prescribed and torque-driven modes | Loop closure, DOF/rank, dead-center diagnostics, acceleration and reaction; infeasible assembly. |
| INT-04 | CAD tooth proxies → CCD/contact/material laws → loaded gear transmission | Tooth engagement, separation/slip, torque/reactions, mesh/time convergence; ideal coupling must not secretly enforce ratio. |
| INT-05 | Contact stack/grasp → contact forces → sensors/controller | Friction bounds, penetration/residual, contact wrench and observation timestamp; nonconvergence and capacity exhaustion. |
| INT-06 | CAD flexible shaft/beam → mesh/material → gear hub attachments → transient/modal output | Mesh quality, natural frequencies, stress/displacement convergence and interface work; inverted element and invalid law. |
| INT-07 | Robot exchange → IK → differentiation → trajectory optimizer → controller → independent replay | Collision clearance, dynamics/effort/joint constraints at and between knots, objective/status, singular/infeasible failures. |
| INT-08 | Checkpoint → concurrent independent rollout → cancellation/shutdown → restoration | Accepted-state identity, controller/random/integrator continuation, no state leakage, race or dangling observation view. |
| INT-09 | Native/WASM/Embedded and GPU profiles using the same admitted mechanism | Exact capability manifests, separate target evidence, shared synchronization semantics, declared numerical equivalence and measured transfers. |
| INT-10 | Vehicle/granular/fluid extension → coupled mechanics → domain observations | Calibrated domain, interface balances, refinement, resource and participant-failure contracts. |

## 6. Implementation readiness and unresolved choices

This requirement inventory is reviewable; implementation architecture and numerical capability claims remain unvalidated. No ready-to-implement declaration is made for the complete system. Each work item starts only when its subordinate contract and relevant dependency behavior have been checked.

| Choice still to be resolved by its owning implementation work | Required resolution evidence |
|---|---|
| Concrete public Swift APIs and actual SwiftPM target boundaries | Downstream usage contract, dependency DAG, child DESIGN.md files, actual behavior prototypes for consequential assumptions. |
| Native numerical algorithms and sparse linear algebra dependency | Matched equation/domain prototypes, residual acceptance, allocation/latency measurements and platform availability. |
| Clean swift-CAD revision and complete geometric moments/proxy queries | Pinned public API behavior and success/failure CAD integration fixtures; absent geometric capability stays owned by CAD. |
| Toolchain/SDK versions and precise target capability subsets | Installed/official release identity, module interfaces, compile/link/runtime evidence for each exact combination. |
| Default tolerances, step/workspace policies and benchmark budgets | Evidence-policy owner, scale/range, convergence/calibration studies and measured workloads; no guessed universal constants. |
| Format versions/subsets and external-engine semantic mapping | Format fixtures, loss/failure policy and independent counterpart validation. |
| Constitutive domains, FSI discretization and extension calibration | Stated equations, calibrated parameter/geometry envelope and verified domain fixtures. |

These are implementation decisions deliberately left for their evidence-owning work items. They must be resolved before the affected API/formulation is frozen. They do not permit weakening the required behavior or treating unsupported cases as successful.
