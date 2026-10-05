# Articulated Dynamics Qualification

## Purpose and Scope
Parent: [SwiftMechanics](../../DESIGN.md). No children. Own focused independent evidence for [ArticulatedDynamics](../../Sources/SwiftMechanics/Physics/Dynamics/ArticulatedDynamics/DESIGN.md) IM.AF35.3: real fixed-root spatial scalar-joint ABA forward and inverse-mass queries. Shared synchronous public cases are portable-ready source; a separate Native case checks actual Task cancellation. Qualification is local to the executed frozen graph, target and inputs, not registration or performance evidence.

## Responsibilities and Boundaries
Construct original public KinematicTree, TreeKinematicsEvaluator snapshots, physical COM inertia, gravity and known loads. Consume ArticulatedDynamicsSolving requirements and compare acceleration, original body equations, mass, bias, energy and momentum with independent analytical mechanics. Dense mass/residual produced by the implementation is supplementary evidence, not the acceleration oracle. Root owns producer compilation, profile/registration and shared manifests. Production changes require an actual counterexample and child DESIGN first; no unrelated supplier changes.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [ArticulatedDynamics](../../Sources/SwiftMechanics/Physics/Dynamics/ArticulatedDynamics/DESIGN.md) | verifies | ArticulatedDynamicsSolving, policy/result/failure | Fixed spatial scalar tree only |
| [ArticulatedTrees](../../Sources/SwiftMechanics/Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | KinematicTree, TreeKinematicsComputing, original published bias/subspaces | Supplied snapshot acceleration is not ABA acceleration |
| [RigidEquations](../../Sources/SwiftMechanics/Physics/Dynamics/RigidEquations/DESIGN.md) | verifies original evidence | RigidDynamicsInput, body/COM inertia, force channels, MechanicalEnergy | Complete energy requires actual known load metadata |
| [LinearAlgebra](../../Sources/SwiftMechanics/Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalBudget/Work and exact resource errors | Preserve failed known work prefix |
| [Loads](../../Sources/SwiftMechanics/Physics/Loads/DESIGN.md) | depends on | LoadWork, gravity and passive spring/damper responses | Numerical and load budgets remain separate |

## Architecture
```text
public physical tree + supplied q/v/acceleration + real inertia/loads
    -> original kinematic snapshot -> protocol ABA forward/inverse-mass
    -> independent analytical acceleration / Newton-Euler / work checks
    -> exact assertion or original typed supplier failure
shared synchronous cases -> portable source + Native executable/Testing
separate Native cancellation -> owned Task + closed local stream gate
```

## Contracts and Invariants
SI units follow original joints: hinge/screw q rad, v rad/s and effort Nm; prism q m, v m/s and effort N. World vectors, COM tensors, gravity, load reference points and power retain original public conventions. Bodies and coefficients are synthetic exact analytic inputs, not empirical defaults.

| Public case | Independent analytical oracle |
|---|---|
| Offset COM pendulum | m=2, c=(1,0,0), Izz=1: J=3; v=2, gravity torque=-20 and passive damping=-6 give a=-26/3, K=6 and kinetic rate=-52; supplied snapshot acceleration99 cannot become result |
| Serial hinges with velocity bias | l=2, m1=2/I1=1/c1=1, m2=3/I2=2/c2=1, q2=pi/2, v=(1,2): M=[[20,5],[5,5]], C=(-48,6), effort=(-23,16) gives a=(1,1), K=30/rate9 |
| Coupled serial prisms | m=(2,3), collinear axes: M=[[5,3],[3,3]], effort=(13,9) gives a=(2,1); v=(1,2) gives K=14.5/rate31 |
| Branched fixed carrier | Fixed offset carrier connects independent hinge J=3 and prism m=3; effort=(6,12) gives a=(2,4), K=7.5/rate0; fixed mass is retained but cannot generate motion |
| Rotated screw and framed load | pitch=.5, m=2, c=(.2,-.3,.4), off-diagonal COM tensor with Izz=6: J=6+2*(.2^2+.3^2+.5^2)=6.76; anchor rotation about Y and q=.7 do not commute with inertia. Body wrench torqueZ=3/forceZ=2 gives effort4, drive2.76 gives a1, K=13.52/rate13.52. Equivalent world wrench must produce same result; missing load energy stays explicitly unavailable |
| Inverse mass and normalization | Serial source has nonzero velocity, bias and additional known loads; rhs=(25,10) and M above give a=(1,1) while retained energy remains original full-source energy. Physical acceleration must be independent of caller valid coordinate/energy/time scales |
| Refusal and work | Exact unsupported root/joint/gravity/reaction sources, identity/frame/velocity/layout mismatch, scalar pivot policy, exhausted arithmetic/iterations/storage/load work and callback cancellation; failed known prefixes are retained |

Assertion tolerances are fixed at 1e-9 relative to max(1, magnitude), and do not alter producer acceptance. Direct vector momentum checks use mass times actual COM velocity and world rotated tensor times angular velocity plus COM cross momentum, without production inertia actions. Native Task cancellation is initiated before releasing the stream gate; producer must return its own `.cancelled`, with no successful result or unexplained work.

## Runtime Flows
Each case constructs a local model and explicit budgets, invokes the original protocol and checks independent scalar/vector physics. Expected failures inspect ArticulatedDynamicsFailure.cause directly without casts or successful fallback. A failed trial/query returns no result. Native public runner invokes all seven synchronous cases and the separately owned cancellation case. Testing invokes the same public methods with one-minute test limits; external watchdogs bound build/link/runtime.

## State, Ownership, and Lifecycle
All tree/input/policy/result owners are immutable Sendable original values. Fixture arrays/work are exclusive local values. No global mutable state, shared raw pointers, cached provider or stream is published. Native cancellation gate is local AsyncStream/continuation; defer finishes it and owned Task is awaited. Native/WASM/Embedded share synchronous fixture storage and Sendable contracts; Native async source is a separate compilation owner, not a weakened Embedded branch.

| State | Native | WASM | Embedded |
|---|---|---|---|
| Inputs/results | immutable original Sendable | same source contract, not yet executed | same source contract, not yet executed |
| Numerical/Load work | local inout | same exclusive owner | same exclusive owner |
| Cancellation gate | local owned stream/Task, awaited/finished | not in synchronous fixture owner | not in synchronous fixture owner |

## Failure, Concurrency, and Constraints
Finite small trees (up to four bodies/two active coordinates), bounded assertions and loops. Work budgets are explicit and generous for physical cases, deliberately minimal for refusal cases. Fresh immutable2363 producer depot and matching module metadata are checked per object/source SHA before linking; no mixed-source producer objects. Fixture-only Native build uses final driver jobs4 and external watchdog900, library120, public60/Testing120. Additional cache budget<=256MiB beyond retained producer evidence. No cold producer/profile operation without root coordination; no process outside owned scope is killed.

## Verification and Change Impact
Original ABA preparation, world-origin inertia, X dual transport, reverse scalar elimination, forward recovery and post-candidate Newton/Euler/energy acceptance were read, along with TreeKinematicsEvaluator, original gravity/load/energy assembly and FoundationVerification DynamicsVerification. Existing Foundation checks qualify suppliers, not this ABA. Successful Native behavior must retain exact producer and fixture hashes, actual driver argv, original typed failures and signing/runtime receipts separately. Ordinary/Embedded WASM profile behavior, individual registration, performance/stack scaling, floating/multi-axis/prescribed/constrained domains and general vehicle integration remain unqualified until their own evidence.


## Selected Portable Profile Preparation
Preparation owns only the private `profiles/` graph and this evidence appendix. It does not change the production fourteen Swift files or any six Native fixture Swift files. The original Native receipt `3b0aba0088cf25a9dd290a2ef2537ab3e8d75a95d9431b41813c2a99eebfab5b` and original DESIGN bytes remain immutable evidence in the private preparation directory; this appendix is a subsequent preparation record, not a rewritten Native receipt.

The selected graph uses the original committed qualified baseline `4d16dfdeed329eb425f8f54dc171793903bc55e5` (inventory `6ce46bfe113b64f48957d91d9d49d259ab85ce1dc2b5e1f224e16f2cd0e1d25c`) and its original 1562 included Swift paths, plus fourteen byte-identical ArticulatedDynamics subjects: 1576 production sources. The original baseline manifest exclusions determine inclusion; no latest live source or AF31 substitution enters the private graph. Per-file source binding is authoritative in `profiles/source-freeze.json`.

| Original public arrow | Actual source path and boundary |
|---|---|
| Shared Fixtures.body/input -> physical records/tree/snapshot | BodyRecord3D, KinematicTree, TreeKinematicsEvaluator; direct public constructors/evaluate, no machine lowering |
| Shared Cases -> ArticulatedDynamicsSolving | ReferenceArticulatedDynamics forwards original input/work to ArticulatedPreparation and ArticulatedRecursion |
| Candidate -> original equations/power | ArticulatedAcceptance -> PhysicalRigidDynamicsInput(spatial:) -> RigidEquationKernel.assemble/originalInertialForce/energy; original AF31 source bytes match Native |
| Passive/gravity inputs -> physical work | ScalarLoadEvaluator and GravityEvaluator retain original LoadWork and energy metadata |

All 1562 baseline paths were compared to original Native2363 per-source binding. 1561 match. The sole difference is `Modeling/Machines/MachineDefinitionContext.swift`: baseline `efb31cf13b15cf32bfcc0a2c29a71268adf915148ad836084a3287fa9d18a48a`, original Native `366645d4c7570d415c2defe9fb71f1faac2b8adb637ba1ca5a9c5fad48969f11`. Original Context lowers Machine declarations; Native adds separate AF34 structural drafts. The selected direct public tree/input path and its articulated-tree, load and original physical equation callees do not call Context or machine definition compilation. Retaining the qualified original Context is an explicit graph choice, not a claim that the two full modules are identical. Original AF31 PhysicalRigidDynamicsSystem remains `9bc5da1d4bef1e3f7ec800ee1629dd70631b95bf0d198f09b556de50d0f75b7e`.

Three common fixture sources (Cases, Fixtures, Error) retain exact Native SHA and analytical oracles. A private synchronous executable adapter invokes only the existing seven public methods. NativeCases, awaited cancellation, Native Runner and Swift Testing are excluded from portable compilation. No Embedded branch weakens failure, Sendable, storage or isolation. Producer callback cancellation still belongs to the seventh synchronous case.

| Pending profile contract | Preparation selection / future acceptance |
|---|---|
| Compiler / SDK | Installed Swift 6.4.0 RELEASE toolchain; ordinary `swift-6.4.0-RELEASE_wasm`, Embedded `swift-6.4.0-RELEASE_wasm-embedded`, target `wasm32-unknown-wasip1`; pin installed Info.plist / SDK / toolset metadata hashes |
| Build bounds | Native build engine, final jobs4 and WMO frontend threads4; record actual complete frontend file list equal to frozen1576, not planned argv alone |
| Embedded Unicode | Explicit private manifest trait links original SDK Unicode tables only for Embedded; ordinary retains its original SDK runtime |
| Stack / execution | Preserve original linker reservation131072; decode every stack-pointer write, require decoded writes == inserted guards >0 and exact lower bound; guarded seven-case run succeeds before raw run, retain raw hash |
| Evidence | Original physics/tolerances unchanged; compiler/LLVM/runtime/archive are pending root queue and resource lease. Preparation is not target qualification, performance evidence, individual registration or full leaf closure |

The preparation receipt records actual small source-copy allocation and pending execution commands. Cold profile resources and watchdogs are re-evaluated by the root queue; no cold process begins during preparation. Changes to called lower sources, subject bytes or common fixture bytes invalidate this selected handoff and require a new exact graph rather than old-module/new-source mixing.

## Complete Registered Native1924 Composition Evidence

The root executed the unchanged selected cases against committed base `1931977e9cbb00322556db5341b9a4f01ba56eeb` containing all1910 registered production Swift files plus the original14 ArticulatedDynamics files:1924. Exact Context `366645d4c7570d415c2defe9fb71f1faac2b8adb637ba1ca5a9c5fad48969f11` belongs to that base. All14 production files and six fixture Swift files retain their original bytes and analytical/tolerance/failure oracles. The original Native2363 receipt remains separate historical evidence; it is not used as a current whole-graph success claim.

| Proof boundary | Actual evidence |
|---|---|
| Complete source composition | [candidate-source-freeze.json](../../.build/af35-articulated-dynamics-qualification/registration/candidate-source-freeze.json), SHA `e5a92c1b255c0a18375466619d7da553b4f03b455220db2cbf8dd1b9384d0784`; actual compiled source list equals all1924 paths, SHA `061bb8f328599fe2bd2af1bad025c5d99c0742f78fa0366795aa4698b0de5670` |
| Original source to object and test link | [canonical-selected-bindings.json](../../.build/af35-articulated-dynamics-qualification/registration/canonical-selected-bindings.json), SHA `d9575e94b97c401876c0bb1a15c9e49dd0dacad03e689d654645779107ccee44`: all14 producer objects plus four original support objects and original test object actually linked |
| Complete matching module/object bytes | [canonical-production-object-inventory.json](../../.build/af35-articulated-dynamics-qualification/registration/canonical-production-object-inventory.json), SHA `9ebb980c6bf8d309c8ff370ab1d34ee64ca815ee20ad5000cecd285dcbbf83e5`; all1924 object/source bindings and three production module metadata checked before/after runtime; the actual support module metadata are also retained in the final receipt |
| Original physical behavior and Native cancellation | [canonical-native-receipt.json](../../.build/af35-articulated-dynamics-qualification/registration/canonical-native-receipt.json), SHA `93157e799dd25cb0436c049f60d1968f9aca157137ee7cc45ec2c445730b73e3`: actual eight Swift Testing cases and eight public calls passed; the original async public Runner includes seven synchronous physical/refusal cases and the eighth awaited Task cancellation. Public output equals the original eight lines exactly |
| Native execution identity and bounds | Swift6.4.0 RELEASE, matching MacOSX27.0 SDK, arm64-apple-macosx13.0, actual effective jobs4; command deadlines,128MiB additional allocation envelope,768MiB global floor with16MiB reaction margins. Every command exited0, including strict public signature verification |

Original executed private manifest SHA `41512ab307b3077a10c65b0fd073b96ea409b5a508b60737d3d939ba4253af13` and root binding SHA `33438b9f158e0af29aeaaef64add72b17de94da3e0adba474f9f49adb736f105` remain unchanged. Its child DESIGN exclusion was inserted in an earlier support target; root copied only14 Swift files into the private production child, so no physical/source input changed. The separately named [metadata correction](../../.build/af35-articulated-dynamics-qualification/registration/design-exclusion-metadata-correction.json) moves only that non-Swift exclusion to SwiftMechanics, retains all other manifest bytes, and is not substituted into the executed proof. No behavior rerun or full rebuild is claimed for that metadata-only correction.

This closes the selected Native composition evidence only. Ordinary/Embedded execution, whole arbitrary supported-tree numerical domain, floating/multiaxis/prescribed/constrained dynamics, vehicle/contact assemblages, performance and stack bounds remain outside this evidence. Documentation changes retain all production14 and fixture6 Swift hashes; root owns shared registration, commit and integration.
