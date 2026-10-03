# Sources and coverage rationale

Reviewed on 2026-10-03. This document records observations and source provenance; normative swift-mechanics requirements belong to [SPEC.md](SPEC.md). These projects supply reference capabilities, not interchangeable numerical models. A documented upstream capability does not establish swift-mechanics support, accuracy, performance, or portability.

## Official references

| Source ID | Project and official source | Observed capability or purpose |
|---|---|---|
| CH-CORE | [Chrono introduction](https://api.projectchrono.org/introduction_chrono.html) | Multibody mechanics, bilateral/unilateral constraints, joints, transmission elements, force laws, contact formulations, integration and static analysis. |
| CH-GEAR | [Chrono gear tutorial](https://api.projectchrono.org/development/tutorial_demo_gears.html) | Constructing mechanisms with gear and pulley links; reference for transmission behavior. |
| CH-FEA | [Chrono finite elements, version 9.0.0](https://api.projectchrono.org/9.0.0/manual_fea.html) | Volume, shell and beam elements; large-displacement flexible parts and rigid/flexible attachment. Versioned historical capability evidence. |
| CH-VEH | [Chrono vehicle module, development](https://api.projectchrono.org/development/group__vehicle.html) | Wheeled/tracked vehicle subsystems, powertrain, terrain, driver and co-simulation. |
| CH-WIDE | [Project Chrono](https://projectchrono.org/) | Optional granular, fluid/solid interaction and accelerated/distributed engineering workloads. |
| SB-CORE | [Simbody repository](https://github.com/simbody/simbody) | Articulated multibody dynamics, forces, contact, forward/inverse dynamics and error-controlled integration. |
| SB-CON | [Simbody constraint implementation documentation, 3.6](https://simbody.github.io/simbody-3.6-doxygen/api/Constraint_8h_source.html) | Coordinate and speed coupling; evidence for general mechanical constraint modeling, not a current-version compatibility promise. |
| SB-API | [Simbody API, 3.7.0](https://simbody.github.io/3.7.0/) | Matter, forces, constraints, assembly and solver responsibilities. |
| DK-MB | [Drake multibody documentation](https://drake.mit.edu/doxygen_cxx/group__multibody.html) | Multibody simulation, model parsing and contact documentation entry points. |
| DK-PLANT | [Drake MultibodyPlant](https://drake.mit.edu/doxygen_cxx/classdrake_1_1multibody_1_1_multibody_plant.html) | Modeling and calculation contracts; solver-dependent coupling and constraint capabilities. |
| DK-CON | [Drake hydroelastic guide](https://drake.mit.edu/doxygen_cxx/group__hydroelastic__user__guide.html) | Distributed compliant contact pressure and representation requirements. Its explicitly selectable point-contact fallback is not adopted as an implicit fallback here. |
| DK-PLAN | [Drake planning](https://drake.mit.edu/doxygen_cxx/group__planning.html) | Optimization-based configuration/trajectory planning, collision checking and static equilibrium. |
| DK-IK | [Drake inverse kinematics](https://drake.mit.edu/doxygen_cxx/group__planning__kinematics.html) | Pose and geometric constraints for configuration solving. |
| DK-TRAJ | [Drake trajectories](https://drake.mit.edu/doxygen_cxx/group__planning__trajectory.html) | Trajectory optimization and related planning contracts. |
| MJ-OV | [MuJoCo overview](https://mujoco.readthedocs.io/en/stable/overview.html) | Articulated systems, actuation, sensors, flexible objects and distinct accelerated execution families. |
| MJ-COMP | [MuJoCo computation](https://mujoco.readthedocs.io/en/stable/computation/index.html) | Generalized-coordinate equations, soft contact, constraint forces, friction, tendons and numerical solving. |
| MJ-MODEL | [MuJoCo modeling](https://mujoco.readthedocs.io/en/stable/modeling.html) | Model compilation, local frames, actuation, material/solver parameters and model exchange. |
| MJ-RUN | [MuJoCo simulation programming](https://mujoco.readthedocs.io/en/stable/programming/simulation.html) | Model/state separation, simulation pipeline, state management and parallel simulations. |
| BT-CORE | [Bullet repository](https://github.com/bulletphysics/bullet3) | Rigid-body collision/dynamics, articulated mechanisms, soft bodies and integration interfaces. |
| BT-GEAR | [Bullet btGearConstraint implementation](https://github.com/bulletphysics/bullet3/blob/master/src/BulletDynamics/ConstraintSolver/btGearConstraint.cpp) | Angular coupling through solver rows. This is not tooth-surface contact simulation. |
| RP-OV | [Rapier documentation](https://rapier.rs/docs/) | 2D/3D simulation and language-binding guide inventory. |
| RP-JOINT | [Rapier joints](https://rapier.rs/docs/user_guides/templates/joints/) | Joint degrees of freedom, motors and impulse versus multibody joint representations. |
| RP-COLL | [Rapier advanced collision detection](https://rapier.rs/docs/user_guides/templates/advanced_collision_detection/) | Contact/intersection queries, events and collision processing hooks. |
| RP-DET | [Rapier determinism](https://rapier.rs/docs/user_guides/templates/determinism/) | Determinism conditions; cross-platform claims require explicit configuration and restrictions. |

Development, stable and master URLs can move. Before using an upstream result as a numerical oracle, record an exact release or commit, build settings, numerical model and fixture configuration. This reading inventory is not that oracle record.

## Reference coverage map

Each row identifies a documented reference area and our proposed requirement family. A blank library name is not evidence that the library lacks that feature. The table is not a feature-count ranking.

| Target area | Reference projects / sources | Requirement families |
|---|---|---|
| Mechanical model and frames | Simbody SB-API; MuJoCo MJ-MODEL; Drake DK-PLANT | MD, RB |
| Articulations and loop closure | Chrono CH-CORE; Simbody SB-CON; Rapier RP-JOINT | JT, CN, KI |
| Gears, shafts and transmissions | Chrono CH-GEAR; Bullet BT-GEAR; MuJoCo MJ-COMP | TR |
| Dynamics, statics and reactions | Simbody SB-CORE; Drake DK-PLANT; MuJoCo MJ-COMP | DY, ST |
| Forces and actuators | Chrono CH-CORE; MuJoCo MJ-MODEL; Rapier RP-JOINT | FL, AC |
| Collision detection and queries | Bullet BT-CORE; Rapier RP-COLL; Drake DK-PLAN | CL |
| Friction and compliant contact | Chrono CH-CORE; Simbody SB-CORE; MuJoCo MJ-COMP; Drake DK-CON | CT |
| Solvers, time integration and events | Simbody SB-CORE; Chrono CH-CORE; MuJoCo MJ-COMP | SO, TI |
| Flexible and deformable mechanics | Chrono CH-FEA; MuJoCo MJ-OV; Bullet BT-CORE | FX |
| Control, differentiation and planning | Drake DK-PLAN / DK-IK / DK-TRAJ; MuJoCo MJ-COMP | CO, OP |
| Sensors, state and parallel rollout | MuJoCo MJ-OV / MJ-RUN; Rapier RP-DET | SE, RT |
| Vehicle, granular and fluid coupling | Chrono CH-VEH / CH-WIDE | EX |
| CAD interoperability and Swift portability | Our CAD-to-mechanics requirement; upstream integration patterns | CA, IO, PF |

## Local swift-CAD observations

Inspected repository: [1amageek/swift-CAD](https://github.com/1amageek/swift-CAD). HEAD during inspection: `9a1ea08e2818e1351908245f2ffaa67aa4fd6477`. The local checkout had uncommitted work; observations include that working tree and do not certify the remote commit alone. No files in swift-CAD were changed for this task.

| Observation | Inspected implementation path | Consequence for this proposal |
|---|---|---|
| It is a Swift CAD implementation with its own geometry/topology stack, not an OpenCASCADE wrapper. | `Package.swift`, `Sources/CADGeometry`, `Sources/CADTopology` | Depend on its public CAD contracts rather than introducing an OCCT assumption. |
| Gear parameters are resolved to shape construction and a swept BRep. | `Sources/CADIR/InvoluteGear/InvoluteGearFeature.swift`, `Sources/CADModeling/InvoluteGear/InvoluteGearFeatureEvaluator.swift` | A generated gear does not automatically define a joint, transmission, motor or contact model. |
| BRep volume checks topology and propagates missing-body failures. | `Sources/CADTopology/BRepModel.swift`, public `volume(tolerance:)` and `volume(of:tolerance:)` | Volume alone does not supply a complete center-of-mass or inertia contract. |
| Document evaluation dispatches through feature evaluation and produces evaluated geometry; meshes are derived data. | `Sources/CADKernel/DocumentEvaluator.swift`, `Sources/CADKernel/DefaultFeatureEvaluator.swift`, `Sources/CADIR/Mesh.swift` | Preserve a geometry revision and topology provenance when deriving physics proxies. |
| Format paths and metadata can have different readiness. | `Sources/CADExchange` format capability and official exchange implementation | Query and verify dependency capabilities; never infer support from a format name. |

These are source-path observations, not runtime validation of a CAD integration. No CAD-to-mechanics adapter exists yet. A clean, pinned dependency and behavioral integration evidence are required by CA-010 before claiming CAD support.

## Interpretation limits

The normative rows are original swift-mechanics engineering requirements informed by these feature areas. They add our failure, ownership, provenance and verification obligations. They do not claim that any reference project implements each row, that their APIs are identical, or that all listed physics can use a single solver. Full API/file-format compatibility and unrestricted material/physics parity are not acceptance claims of this specification.
