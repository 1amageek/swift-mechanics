# Reaction path behavioral evidence

## AF25 reduced planar evidence owner
`PlanarReactionRecoveryTests` uses actual BodyRecord2D/MassProperties2D and PhysicalRigidEquationComputing. Independent pendulum, distinct root/child gravity and slider offset/frame rotation check Fx/Fy/Mz and retained points. Raw off-plane reference/couple cancellation, wrong acceleration/generalized allocation, malformed supplier evidence, zero/precharged gravity reset success/failure, cancellation preservation, numerical reset/resource/cancellation and floating support absence exercise the contract. Existing planar Joints admission requires anchor poses with z==0; no fabricated off-plane snapshot is used as evidence. Existing spatial tests remain unchanged. Owner: [ReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md#af25-additive-reduced-planar-recovery). Root owns actual execution after freeze.

| Actual lower witness | Independent expectation |
|---|---|
| Pendulum m=2, COM X=1, Iz=4, omega=1, alpha=-10/3 | Hinge (-2,40/3,0); root (-2,70/3,0), reported axes Fx/Fy/Mz |
| Two serial X sliders, masses 2/3, first body Rz(pi/2), second X=2; identified world force (10,5) at world Y | Absolute accelerations 5/0; first cut (0,45,70), second (0,30,0), root (0,55,70); shifted and rotated real points |
| Original raw force +10X at world Z=1 and couple -10My | Full shifted transverse couple cancels; hinge (-12,40/3,0), root (-12,70/3,0) |
| Original X slider, prescribed +1Y acceleration, foreign mass 4 replacing mass 2 | Same IDs/frame/reference, unchanged zero X generalized projection, physical Fy 4 instead of 2; invalidSupplierEvidence |
| Same-frame gravity -20Y replacing original -10Y | X generalized projection stays zero; builtin original gravity rejects foreign response after exactly 3 charged units |
| Actual point work followed by zero/precharged ledger reset, success and failure | supplierLedgerReplaced; irreversible admission prefix and original cancellation closure retained |
| Actual point succeeds and then cancels original caller during merge | loadLedgerMerge(cancelled), unavailable marker, admission-only known prefix |

The test helper cancellation flag owns a single Synchronization.Mutex<Bool> with common storage/read/mutation for every target. Its macOS 15 availability is guarded in the test; there is no Embedded-specific state replacement. Remaining fixture arrays and work values are operation-local. Native deadline is one minute per declaration, with the external timeout owned by root. The suite has 11 declarations and 15 parameter-expanded cases.

Owner: [ReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md). Public TreeReactionRecovering executes original Dynamics Newton/Euler and actual Loads/Joints paths.

| Oracle | Body/load owner | Rejected counterexample |
|---|---|---|
| Pendulum analytic F=m*(alpha cross r + omega cross omega cross r)-m*g and T=I*alpha+r cross F | Child body only for hinge; fixed root's independent weight included only in root support | Generalized torque labeled as six-axis support; doubled root weight |
| Vertical static two-link subtree force and offset transverse-load moment | Distinct first/second masses and physical force point | Only child-body balance instead of whole subtree; missing moment shift |
| Rotated frame and translated joint anchor | Actual public snapshot poses and same world reference for both signs | Rotation-only torque or inconsistent action/reaction reference |
| Floating body original free dynamics | Whole free tree; no support owner | Invented support hiding acceleration error |
| Failed paths and ledgers | Caller limits/cancellation; immutable suppliers | Report after ambiguous loads, wrong acceleration, exhausted resources or erased work; zero/precharged callback prefix with reset on both success/failure; original cancellation closure retained |

Native focused tests have deadlines through Scripts/run_with_timeout.py; root owns frozen-source registration and Native/WASM/Embedded public probes. Test fixture is owned independently here; no production source uses it. All mutable test data is local. Injected suppliers deliberately replace ledgers; they are failure oracles, never accepted physical producers.

### AF25 lower Native qualification

The frozen source executed 20 declarations in two suites, including all eleven PlanarReactionRecovery declarations/fifteen expanded cases. Exact Swift 6.4.0 release/macOS 27 arm64, `.build/ar01-native`, `-j 4`, and a 240-second external timeout were used. Logs: `.build/af25-lower-native-tests.log` and the allocation-only `.build/af25-allocation-native-recheck.log`. Original production did not change during test-helper corrections. Source/profile composition is canonical in [FoundationVerification](../../Verification/FoundationVerification/DESIGN.md#af25-lower-integrated-qualification); full upper/root/loop domains remain separate.
