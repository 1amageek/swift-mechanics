# TaskSpace Qualification

## Purpose and Scope
Own independent behavioral fixtures for the selected fixed-root spatial Euclidean TaskSpace controller. Parent registration: [task/package root](../../DESIGN.md). No children. Eight synchronous cases are shared by Native tests and the public executable; a ninth Native test checks actual Task cancellation. Preparation does not establish behavioral qualification.

## Responsibilities and Boundaries
Compile actual mechanical descriptors, evaluate their original tree, assemble complete physical mass and known loads, and invoke the public `TaskSpaceControlling` requirement. Analytic SI oracles own expected results. Production remains the original seventeen files; fixtures do not manufacture successful physical systems/results. This scope does not qualify actuator publication, Runtime enforcement, planar support, manifold/floating control, prescribed anchors, contact allocation, or full joint families.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [TaskSpace](../../Sources/SwiftMechanics/Execution/Control/TaskSpace/DESIGN.md) | verifies | request, policy, typed result/failure | Selected primary/nullspace and additional wrench laws | Explicit damping errors stay visible |
| [Compilation Records](../../Sources/SwiftMechanics/Modeling/Compiler/CompilationRecords/DESIGN.md) | depends on | compile, makeState, evaluate | Actual descriptor and snapshot provenance | Fixed root and complete physical tensors |
| [Jacobians](../../Sources/SwiftMechanics/Modeling/Joints/Jacobians/DESIGN.md) | depends on | point/geometric Jacobians and bias | Original world motion reconstruction | Body-local point and body-origin wrench differ |
| [Rigid Equations](../../Sources/SwiftMechanics/Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | assemble, originalInertialForce, energy | Original Newton/Euler and power checks | Uniform gravity only |
| [Dense Dynamics](../../Sources/SwiftMechanics/Physics/Dynamics/DenseDynamics/DESIGN.md) | depends on | inverseMassProduct/inverse/forward | Actual original physical solver | No fake accepted outputs |

## Architecture
```text
physical descriptor -> qualified compiler -> original state/snapshot
 -> RigidEquationKernel assembly -> public TaskSpaceControlling
 -> original M^-1/J/bias -> weighted Gram -> primary/nullspace
 -> original inverse/forward -> Newton/Euler + point motion/power
 -> analytic SI values + fresh original reconstruction
```

## Contracts and Invariants
All fixture bodies have complete mass/COM/inertia tensors. Static root mass is retained and moves with zero motion. Dynamic masses are 2 kg and, where present, 3 kg; COM tensors are identity kg m^2. Fixed anchors are identity. Snapshot time is 3 s, revision 1. Body/state/layout/frame identities come from the real compiled model.

| Shared case | Independent oracle and falsifiable gate |
|---|---|
| Serial priority | Two X sliders: M=[5,3;3,3], J=[1,1]. Desired 4 m/s^2, secondary [5,7] gives primary [0,4], projected [5,-5], total [5,-1], effort [22,12] N. v=[2,-1] gives drive 32 W, task dual 12 W, K=5.5 J and Kdot=32 W. |
| Weighted scaled axes | Serial X/Y sliders: M=diag(5,3), point J=I. Desired [4,-2], positive weights [9,0.25], nonunit length/time/energy/coordinate scales preserve accelerations and efforts [20,-6] N; power 46 W and K=11.5 J. |
| Hinge bias and gravity | 2 kg at local COM (1,0,0), Izz=1, q=0, omega=3: M=3, COM centripetal -9 X, point (2,0,0) bias -18 X, Jy=2. Desired Y=4 gives alpha=2 rad/s^2; g=-10 Y gives known torque -20 Nm, drive 26 Nm, dual force 3 N, drive 78 W, dual 18 W, K=13.5 J and Kdot=18 W. |
| Additional wrench | One X slider, mass 2, v=2, known applied force 10 N. Additional body-origin 6 N yields total acceleration 8 m/s^2, command power 12 W, known power 20 W, Kdot=32 W. The same motion target has dual 16 N/32 W but drive 6 N/12 W. |
| Rank and damping | One X slider, X/Y rows, desired [4,0], lambda=0.5, secondary [6]: rank=1; primary 8/3, projected secondary 2, total 14/3; primary defect 4/3, leak/secondary defect 2, final residual 2/3. Explicit gates allow these values or reject primary/leak; strict rank refuses. |
| Typed source/domain/shape | Revision/time/frame, wrench origin, duplicate axes/nonfinite command, hybrid/contact request and actual known contact load refuse explicitly. |
| Work and cancellation | Seeded original work prefix retained. Exact measured operation/storage/iteration capacities succeed; one-less operations/storage refuse with bounded prefix. Policy and actual Native Task cancellation publish no result. |
| Supplier failure | Fault-only mass supplier charges thirteen operations then throws, or resets its seeded ledger. Valid work is absorbed, invalid reset retains only known seed. Fault-only linear refusal marks inaccessible supplier work. Successful paths always use qualified concrete suppliers. |

Oracle scalar tolerance is fixed at `1e-8 * max(1, abs(expected))`. Original solver residuals use `1e-10` absolute/relative and pivot `1e-12`; strict task/leak/power/replay gates use `1e-9` absolute plus `1e-10` relative. Damped accepted case alone declares 2 m/s^2 primary/final and 2.1 m/s^2 leak absolute bounds with zero relative tolerance. Refusal cases lower only their explicit requested acceptance gate, not the oracle.

## Runtime Flows
The original snapshot does not retain q. Each success passes the exact original caller position explicitly into reconstruction and reconstructs a snapshot at the returned generalized acceleration, reevaluates actual point acceleration, recomputes original Newton/Euler generalized force and kinetic energy/rate, and compares these to analytic SI expectations. Fresh reconstruction is a supplier composition check; it does not replace independent analytic expected numbers. Public entry calls cases directly, without typed-throws function arrays. Native cancellation cancels its own current Task before the original controller invocation.

## State, Ownership, and Lifecycle
Model, inertia, systems and requests are immutable Sendable values/owners. Every case owns local work and buffers; no shared mutable counters, target-conditioned storage or unchecked isolation exists. Fault witnesses are immutable and used only on failure paths. The producer remains read-only; consumer borrows its module/object paths directly and may link one private dylib without object copies.

## Failure, Concurrency, and Constraints
All unexpected successes/failures and numeric mismatches throw a typed fixture error. Individual compiler/link/runtime commands will have external deadlines, jobs 4, and a consumer new-growth envelope of 128 MiB when the coordinator releases a Native slot. Preparation does not run a compiler, decoder or runtime. Original Native2363 source/object binding is required before borrowing outputs; affected producer regeneration is necessary if any production source is causally changed.

## Verification and Change Impact
Eight public synchronous cases and the same eight Native tests plus one actual Task cancellation are the planned evidence. TaskSpace seventeen source bytes currently match their original Native2363 source inventory and retained source copies; this is source provenance, not behavior proof. Whole-module source compilation does not imply TaskSpace success. Any actual numerical counterexample must repair the owned production contract before rebuilding a matching module/object closure; tolerances/oracles cannot be weakened to pass. Root owns registration, shared design indexes, PROGRESS and Git.

### Prepared source provenance
The intended Native consumer is the immutable original Native2363 pass11 depot, not the newer repaired Attachments/Structural module. Every TaskSpace Swift file matches both that producer's original per-source SHA and retained source bytes. The original `WorldRigidBody` reads snapshot body motion directly; the newer live implementation uses an internal motion projection. The original `PhysicalRigidDynamicsSystem.spatialSystem` performs reconstruction inline; the newer live implementation extracts a helper. These live supplier edits are deliberately absent from this selected proof. Public compiler/model, Jacobian, kernel, DenseRigidDynamics, input and uniform-field contracts were checked against the frozen original implementation. No current-live full-graph equivalence is claimed.

Prepared fixture storage is local and identical across targets. The sole Embedded conditional selects the real `CompilerTarget` enum; it does not change Sendable, mutable storage, or isolation. No Mutex counter or OS availability change is required by this fixture. Native actual Task cancellation is a separate async test; the eight portable public cases remain synchronous.

### Selected Native evidence
The unchanged seven fixture Swift files (sorted basename NUL contents NUL SHA-256 `c6b28605e5e9feb84bc1bf68205bc9ee744d094ac4e8902eab0e89cca4c36afe`) passed all nine Native tests and all eight public cases. A single original2363 dylib was linked directly from retained read-only objects in 0.375 s; fixture-only build/link took 4.689 s, focused test invocation 1.219 s, and public runtime 0.301 s. Original2363 source/object/module metadata hashes were verified before link and after execution. No source copies, object copies, production repairs, fixture repairs, oracle/tolerance changes, cold producer builds or repeated tests were required.

The producer module and support/public declarations target macOS13; SwiftPM's actual Testing and final test runner target macOS14. These are compiler deployment targets, not runtime evidence on a macOS13 host. The pinned Swift 6.4.0 release compiler and MacOSX27.0 SDK were used; all actual compiler argv effective jobs were 4. The deprecated documented Native backend warning is retained. Actual process-group watchdogs used 120 s for link, 180 s for build, 60 s for test/public and 30 s for read-only link inspection. Measured owner storage remained below 98.1 MB within 128 MiB; all sampled free space exceeded the 640 MiB floor. No shared mutable fixture state or target-dependent synchronization exists.

Exact process/source/object/link/artifact bindings and proof limitations are retained in [Native behavioral receipt](../../.build/af35-task-space-qualification/consumer/native-behavioral-receipt.json). The original prepared design and freeze remain separately retained. Evidence is Native selected-domain only; ordinary/Embedded and canonical current-live registration remain subsequent root-owned integration work.

### Native registration preparation
The separate [registration preparation](../../.build/af35-task-space-qualification/registration/DESIGN.md) uses complete committed HEAD5aa868a1796 plus unchanged TaskSpace17, with a mandatory root refresh after preceding Hex integration. Registered old Context is retained and the private Builder graph is isolated. Original2363 selected9/public8 proof remains valid for its own source closure; the complete canonical composition has not run in this preparation. All seven Swift fixtures, independent SI expectations, error gates and tolerances remain unchanged. Portable proof remains open. This paragraph is a separately scoped documentation update, not a replacement of retained earlier design freezes.

## Full registered1830 Native composition

Root retained exact committed Hex1813 and added only frozen TaskSpace17 plus unchanged fixture7. Actual17 primary emissions, full1830 source/object/module inventory and actual test/public linker inputs are bound by `.build/af35-task-space-qualification/registration/canonical-native-receipt.json` SHA `b2f1a9809beaaf0eacf608beb0f96c094af6b65e4b6c74669e9b15d5175f01fe`. Original9 tests and8 shared public cases passed with no oracle, physical source or tolerance repair: build8.136s, tests1.023s, public compile0.607s and runtime0.432s. All1830 objects/module/source hashes matched after runtime. Fixed Swift6.4.0, current SDK/macOS13 production/public target and4 compiler jobs are recorded; this current-host evidence is not older-host or portable runtime proof. Incomplete domain refusals remain in production source.
