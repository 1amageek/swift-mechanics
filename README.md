![swift-mechanics — engineering mechanics in Swift](.github/social-preview.jpg)

# swift-mechanics

**Declarative engineering mechanics in Swift.**

Describe a machine as a composition of bodies and joints, then compile and evaluate it through explicit mechanical and numerical contracts. The project targets motion, forces, torque, reactions, contact and deformation, with control and optimization built on the same foundations.

The package exposes one public module: `SwiftMechanics`.

## Project status

**Active development.** The declarative foundation and selected mechanics paths are implemented and behaviorally verified. The complete specification contains **210 requirements across 23 domains**; that target is not yet fully implemented or verified. Public APIs are still evolving.

Capability claims are specific to the implemented model, input domain, solver and execution profile. Selected macOS, WASI and Embedded WASI paths have runtime evidence. This does not establish support for every feature on those platforms, browser execution, actual WASI multithreading, Linux or iOS.

Use [PROGRESS.md](PROGRESS.md) and the corresponding component designs to check current implementation and evidence. The feature specification is a target contract, not a list of available features.

## Declarative machines

`Machine` provides a SwiftUI-like composition model through `var body: some Machine` and `MachineBuilder`. The intended authoring model declares bodies and their connections directly inside `body`:

**Target API sketch:** the high-level primitives below are not implemented yet. The authoring surface describes 3D machines without dimensional suffixes. This example illustrates structure; geometry, inertia and initialization inputs are omitted, so it is not a runnable simulation.

```swift
import SwiftMechanics

struct HingeAssembly: Machine {
    var body: some Machine {
        RigidBody("base") {
            RevoluteJoint("hinge", axis: .z) {
                RigidBody("arm")
            }
            .offset(z: 0.1)
        }
        .fixed()
    }
}
```

Declarations should produce immutable mechanical definitions; identity, units, physical parameters and connections are admitted during lowering and compilation. Mutable simulation state belongs to execution owners rather than stored body or joint objects in the declaration.

Nesting expresses articulated structure. Cross-references close loops or connect independent components; named ports express multi-terminal transmissions. Placement, persistent constraints, force laws and runtime engagement have distinct meanings. The declaration tree is not the physical connection graph.

The [declarative authoring design](Sources/SwiftMechanics/Modeling/Machines/DESIGN.md#target-declarative-authoring-contract) owns the structure catalog, coordinate conventions, example syntax, lowering obligations and implementation prerequisites. Its sketches are target design, not a capability claim. Existing planar kernels and low-level records remain part of the specification.

The implemented foundation currently uses `MachineBody` and `MachineJoint` to compose validated records. Its builder supports conditionals, `switch`, optional content, reusable scoped instances, type erasure through `AnyMachine`, and bounded lazy repetition through `ForEachMachine`.

The target design also provides optional display labels: a content-only initializer, a `label: "Motor"` convenience, or a trailing `label: { Text("Motor") }` closure. The explicit mechanical ID is separate from the display label. These forms are planned, not implemented; the [label and initializer contract](Sources/SwiftMechanics/Modeling/Machines/DESIGN.md#optional-labels-and-initializer-contract) owns examples, metadata lifetime and overload equivalence. The illustrated `Text` is a library label declaration and does not introduce a SwiftUI dependency.

`MachineDefinition` lowers declarations into a descriptor and delegates physical admission to the mechanical compiler. A successfully constructed declaration is not yet a valid compiled model. Simulation steps operate on compiled models and state; they do not reevaluate the declaration.

See the [Machine contract](Sources/SwiftMechanics/Modeling/Machines/DESIGN.md) and [compilation tests](Tests/SwiftMechanicsMachineTests/MachineCompilationTests.swift) for actual compilation, articulated motion, scoped identity and failure behavior.

```mermaid
flowchart LR
    Declaration[Machine declaration] --> Lowering[Bounded lowering]
    Lowering --> Compiler[Mechanical compiler]
    Compiler --> Model[Immutable compiled model]
    Model --> Runtime[State and numerical evolution]
    Runtime --> Output[Motion, forces and diagnostics]
```

## Mechanism catalog (target)

The following mechanisms and structural relationships are the intended declarative scope. **This is a target catalog, not a claim that every entry is implemented or qualified.** Current availability depends on the admitted model, formulation and execution profile; see [PROGRESS.md](PROGRESS.md) and the corresponding component evidence.

This reader-facing index follows the canonical [mechanical structure coverage](Sources/SwiftMechanics/Modeling/Machines/DESIGN.md#mechanical-structure-coverage). That design owns declaration forms, coordinate conventions, dependencies and verification obligations. Composite mechanisms are built from the same `Machine` primitives and relationships; each catalog entry does not require a separate primitive API.

| Family | Mechanisms and structures | Declarative representation |
|---|---|---|
| Composition | One rigid body; rigid assembly | Rigid owner content or explicit fixed connection |
| Supports | Fixed, moving and floating supports | Explicit root/support mode and bindings |
| Graph topology | Serial chains, branches, closed loops, parallel mechanisms, shared loops, independent mechanisms | Nested articulation plus reference connections |
| Reuse | Repeated/reusable assemblies | Scoped Machine instances and bounded repetition |
| Coordinates | Local and mounting frames | Identified frames and placements |
| Geometry | Coincident points; coaxial/concentric; parallel; perpendicular; specified angle | Kind-specific geometric relations |
| Distance | Distances and offsets between points, axes and planes | Placement or persistent relation, explicitly distinguished |
| Guided motion | Point-on-line, point-on-plane, point-on-curve, point-on-surface | Attachment and admitted guide references |
| Layout | Symmetric, circular, linear and grid patterns | Placement/repetition composition, not implicit runtime constraints |
| Elementary pairs | Fixed/weld, revolute, prismatic, screw/helical, cylindrical, universal, spherical, planar, free/floating | Concrete joint with nested or explicit endpoints |
| Common shafts | Rigidly mounted gears/pulleys/rotors; compound gears | One rigid shaft owner with constituents |
| Independent coaxial shafts | Independent rotation; nested hollow shafts | Distinct bodies/joints with axis alignment |
| Shaft mounts | Keyed/fixed spline; sliding spline | Explicit rotary and axial connection semantics |
| Shaft couplings | Rigid coupling; flexible coupling | Fixed connection or elastic frame relation |
| Bearings | Radial/thrust support; locating/nonlocating support; multiple bearings | Supported directions at declared mounts; explicit ideal/detailed model |
| Articulated shaft drives | Constant-velocity joints; Cardan shaft | Joint/transfer composition |
| Gear pairs | External/internal spur; helical; bevel; worm; hypoid | Gear geometry plus explicit mesh formulation |
| Gear networks | Simple, compound and reverted trains | Rigid mounts and mesh relationships |
| Multi-terminal drives | Planetary gears; differentials; power split | Named mechanical roles and admitted terminals |
| Variable/friction transfer | Noncircular gears; friction wheels | Position-dependent transfer or explicit contact law |
| Flexible transmissions | Open/crossed/timing belts; chains and sprockets | Routes, winding and explicit transfer/contact laws |
| Cable systems | Wires; tendons; capstan/wrapping; fixed/moving pulleys; pulley blocks | Ordered endpoint/guide route and tension law |
| Rotary-linear drives | Rack/pinion; lead screw; ball screw | Rotary and linear terminals with an explicit formulation |
| Composite reducers | Strain-wave/harmonic and cycloidal drives | Composite Machine with qualified transfer/contact/deformation model |
| Four-bar structures | Four-bar; crank-rocker; double-crank; double-rocker; parallelogram | Body/joint composition and loop closure |
| Rotary-reciprocating links | Slider-crank; offset slider-crank; Scotch yoke | Revolute/prismatic structure plus loop/slot relation |
| Multi-link structures | Toggle; pantograph; scissor; Watt/Stephenson six-bar; general multi-bar | Reusable link compositions and shared loops |
| Path/spatial linkages | Straight-line generators; spatial and spherical linkages | Spatial mounts and composite loops |
| Robots | Serial robot; Stewart platform; Delta; other parallel robots | Serial/parallel composites and admitted actuation |
| Vehicle linkages | Double-wishbone/MacPherson suspension; steering/Ackermann linkage | Bodies, joints, loops and force elements |
| Cams | Disc, translating, cylindrical/barrel, grooved and conjugate cams | Cam/follower geometry and explicit contact/ideal law |
| Followers | Roller; flat-face; tip followers | Shape-specific follower connection |
| Intermittent mechanisms | Geneva; ratchet/pawl; escapement | Composite contact, direction and engagement relations |
| Directional transmission | One-way/overrunning clutch | State-dependent transmission law |
| Passive force elements | Translational/torsional springs and dampers; series/parallel networks | Point/frame/rotary terminals and constitutive law |
| Compliant supports | Bushings; elastic mounts | Frame terminals and multidirectional law |
| Flexible structures | Flexible shaft/link/beam; flexure mechanisms | Deformable constituents and boundary bindings |
| Mixed rigid/flexible structures | Rigid-to-flexible attachments | Body mount to material point/node/region binding |
| Constitutive state | Preload; nonlinear and history-dependent laws | Explicit parameters and continuation state contract |
| Tension-only systems | Slack/taut cable | Route and unilateral tension law |
| Contact | Unilateral/frictional contact; no-slip/slipping rolling; impact/rebound; tooth contact | Geometry pairs/sets and explicit contact or velocity law |
| Clearance | Backlash; bearing/guide clearance | Dead-zone/contact model and declared geometry |
| Stops | Joint limits and physical stops | Coordinate limit or contact surface |
| Switching connections | Friction/toothed clutch; brake; latch; lock | Terminals, explicit model and declared input/condition |
| Release | Breakable/disengaging connection | Physical criterion and accepted transition |
| Actuation | Torque/force drive; prescribed angle/position/speed | Typed input and effort or motion authority |
| Drive composition | Elastic drive; hydraulic/pneumatic cylinder; tendon/cable drive | Mechanical and domain ports plus qualified suppliers |
| Reactions and networks | Rotor/stator; housing support; multi-terminal power network | Explicit support and power-conjugate terminal bindings |

## Scope

The target includes the following areas. Each area has its own supported subsets and remaining work.

| Area | Target responsibilities |
|---|---|
| Models and kinematics | Units, frames, identity, inertia, joint manifolds, assembly and constraints |
| Dynamics and transmission | Forward and inverse dynamics, gears, drives, passive loads and physical reactions |
| Contact and time evolution | Collision queries, friction, impact, integration and hybrid events |
| Flexible mechanics and analysis | Constitutive laws, elements, equilibrium, vibration and stability |
| Control and optimization | Observations, feedback, derivatives, identification and planning |
| Execution and exchange | State ownership, rollback, checkpoints, replay and bounded model codecs |
| Engineering integration | CAD-derived mechanical input and selected particle, fluid and coupled models |

[SPEC.md](SPEC.md) defines the input domains, failure conditions and acceptance evidence for every requirement. Project Chrono, Simbody, Drake, MuJoCo, Bullet and Rapier inform the scope; the project does not promise complete compatibility with their APIs or extensions.

## CAD and mechanics

Geometry and mechanics have separate authorities. **swift-CAD** is the intended geometry dependency for a separate CAD adapter package. The current core package has no swift-CAD dependency, and CAD integration remains planned.

```mermaid
flowchart LR
    CAD[swift-CAD: geometry and topology] --> Adapter[Planned CAD adapter]
    Input[Explicit mechanical records] --> Mechanics[SwiftMechanics]
    Adapter --> Mechanics
    Mechanics --> Results[State, physical quantities and diagnostics]
    Results --> Application[Application and visualization]
```

swift-CAD owns geometry, topology and geometric queries. swift-mechanics owns mechanical interpretation, inertia, joints, constitutive laws and simulation state. Applications own visualization and interaction. A missing CAD query remains a dependency gap rather than becoming a second geometry kernel here.

## Using the package

The development baseline is **Swift 6.4.0**. The manifest declares macOS 13 for the library; individual operations and tests have additional availability requirements. For example, Mutex-based runtime paths require the platform's `Synchronization` support. Deployment declarations alone are not runtime qualification.

Until a release is available, add the current development branch to your Swift package:

```swift
.package(
    url: "https://github.com/1amageek/swift-mechanics.git",
    branch: "codex/specification"
)
```

Add the product to your target's dependencies:

```swift
.product(name: "SwiftMechanics", package: "swift-mechanics")
```

Use `import SwiftMechanics`. Pin a reviewed commit when reproducible integration is required.

## Verification

Run focused Native tests with the repository's timeout wrapper and the pinned toolchain:

```sh
python3 Scripts/run_with_timeout.py 240 \
    swift test --filter SwiftMechanicsMachineTests
```

The package also provides `mechanics-core-verification` and `mechanics-foundation-verification` executables for public API qualification. WebAssembly verification uses matching Swift 6.4.0 SDKs, separate build paths and actual WASI execution. Compile and link success alone do not establish runtime support.

The [Core verification design](Verification/CoreVerification/DESIGN.md) and [Foundation verification design](Verification/FoundationVerification/DESIGN.md) own the exact execution profiles and recorded evidence. Changes to physics require appropriate physical oracles, residuals, conservation or balance checks, and explicit failure tests.

## Documentation and contributions

| Document | Responsibility |
|---|---|
| [PHILOSOPHY.md](PHILOSOPHY.md) | Design values and decision principles |
| [AGENTS.md](AGENTS.md) | Repository workflow and contributor instructions |
| [SPEC.md](SPEC.md) | Functional requirements and acceptance contracts |
| [DESIGN.md](DESIGN.md) | System architecture and child design index |
| [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | Requirement ownership, prerequisites and parallel handoffs |
| [PROGRESS.md](PROGRESS.md) | Current implementation progress and qualification |
| [SOURCES.md](SOURCES.md) | Reference observations and dependency investigation |

Contributions should identify the requirement, design owner, supported domain and behavioral evidence they change. Follow the prerequisite graph, preserve other contributors' work, and distinguish a verified subset from completion of an entire requirement.
