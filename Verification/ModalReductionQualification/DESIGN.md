# Modal Reduction Stress Qualification

## Purpose and Scope
Own independent public behavioral witnesses for the additive Tet4 modal stress reconstruction operation. Parent: [Verification](../DESIGN.md). No children. [Production contract](../../Sources/SwiftMechanics/Physics/Flexible/ModalReduction/DESIGN.md) is authoritative. Source preparation is not behavioral qualification.

## Responsibilities and Boundaries
Use public validated Tet4/material, physical modal preparation, initial state and stress APIs. Own fixed literal analytic current-F Green-strain/stress/energy/force/power oracles and typed failure/work/cancellation witnesses. Do not claim modal evolution accuracy, truncation convergence, general finite-rotation objectivity, material history or beam qualification.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [ModalReduction](../../Sources/SwiftMechanics/Physics/Flexible/ModalReduction/DESIGN.md) | depends on | ModalReducing preparation/initialState/new stress overload | Actual source reconstruction | Original ConstitutiveCallWork overload remains unsupported |
| [FieldOutputs](../../Sources/SwiftMechanics/Physics/Flexible/FieldOutputs/DESIGN.md) | depends on | Qualified constant-F assigned law query | Current physical response | Modal composition needs fresh matching producer |
| [Verification](../DESIGN.md) | parent | Root-owned registration/evidence | Public fixture owner | No shared manifest edits here |

## Architecture
```text
unit reference Tet4 + actual polynomial material + constrained original DOFs
 -> public modal preparation (all six positive modes retained)
 -> independent physical increments projected via mass Gram
 -> public initialState -> explicit binding/location/policy/field ledger
 -> real current-F query -> independent literal material/force/power oracles
```

## Contracts and Invariants
Unit Tet4 reference volume 1/6, nodes (0,0,0),(1,0,0),(0,1,0),(0,0,1), original IDs10...13, cell50, mesh revision7. Fix original coordinates [0,1,2,4,5,8]; retain all six modes. K=12, mu=3, lambda=10, nonlinear beta=0, reference density6, declared Green-strain norm<=0.5 and J>=0.2. Operating F=I, selected displacement node2.x=.2 produces F=[[1,.2,0],[0,1,0],[0,0,1]]. A second real operating-state preparation uses F01=.125 and modal increment .075, requiring the same final F01=.2; reference-position reconstruction instead of operating-position reconstruction must fail this oracle. Fixed-before-run literal E=(E01=.1,E11=.02), S=[[.2,.6,0],[.6,.32,0],[0,0,.2]], P=[[.32,.664,0],[.6,.32,0],[0,0,.2]], Cauchy=[[.4528,.664,0],[.664,.32,0],[0,0,.2]]. Energy density .0632, stored energy .0632/6. With node2 velocity .3X, P:Fdot/6=.0332. Current stress must differ from linear infinitesimal frozen-tangent stress (P00=0,P01=.6); this counterexample detects fake tangent recovery. Independent force oracle is column(P)/6 and node0 negative column sum/6. Barycentric [1/4]*4 gives reference(.25,.25,.25), current(.30,.25,.25). No nodal smoothing.

All-mode coordinate admission uses Phi^T M d/(energyScale*timeScale^2); separately verify the original physical displacement recovered through Phi, not assume the projected vector reproduces d. Tolerance is fixed absolute1e-12 plus relative1e-9 times max magnitudes. Original-node position and velocity, source/frame/material/mesh/cell/time/location and exact expected binding must match. New explicit ledger begins at0 and records actual field evaluate; old signature must reject with its ledger unchanged.

Literal source-derived successful charges are outer935 + field evaluate1963 + sample864 =3762; simultaneous model/nodal1234 + field snapshot826 =2060 scalar units. Zero call budget rejects after1734 operations; storage2059 leaves supplier825 and rejects before field traversal at caller935; operation cap3761 leaves supplier2826 and rejects the final64 charge at caller3698. These predictions were checked by the selected Native evidence below.

Six synchronous cases cover constitutive reconstruction; location/source records; original force/energy/power; finite-domain and old-signature refusal; work and call limits; cooperative early/late cancellation. Native seventh awaits a self-cancelled Task through the same operation. Initial preparation performed no execution; the fresh Native evidence below records the later root lease and actual route.

## Runtime Flows
Build actual mesh/model -> derive original physical modal inputs -> call actual producer -> compare independent literals or exact typed causes. Cancellation counter owns each operation checkpoint and never invokes external callbacks under lock.

## State, Ownership, and Lifecycle
Immutable Sendable public suite and per-call values. Native/WASM/Embedded use the same Synchronization.Mutex<Int> operation-owned cancellation counter and withLock entry points. Actual macOS SDK requires15 for this fixture helper; producer macOS13 and fixture macOS15 are distinct. No global cache or unsafe concurrency.

## Failure, Concurrency, and Constraints
Bounded tiny mesh (4nodes/1cell), six coordinates, and explicit NumericalWork/FieldConstitutiveWork limits. Failure preserves original typed modal/field/material/numerical cause; no fallback or tolerance weakening. Original source freezes and lower evidence remain unchanged. Initial compiler/runtime leases were held; the fresh route below records the actual matching-source execution.

## Verification and Change Impact
The fixture contract contains six identical public synchronous cases plus Native awaited cancellation. Matching source/module/object/link and per-source hashes must be checked before and after each changed-snapshot Native execution; lower Native1960 FieldOutputs evidence alone does not prove this composed path. Any actual source defect requires design-first causal fix and fresh matching producer. Portable execution and full/reduced transient/frequency convergence remain unverified.

### Fresh committed-head Native recovery preparation
The historical .build receipts/depot have been lost; their recorded identifiers remain historical references and are not executable evidence. Current preparation reconstructs exact committed HEAD `4ac336117d2a840ca79c344a62d79fd48ee6e9db`:1983 registered SwiftMechanics sources under the original excludes plus only current ModalReduction12, giving1995. Committed FieldOutputs and FiniteStrainKinematics are copied from that same commit, without Terrain18 or other WIP. Original six synchronous physics/work/refusal cases and Native awaited cancellation remain unchanged.

Private `.build/af36-modal-native` owns producer, consumer and fresh receipts. Producer macOS13 is a real dynamic SwiftMechanics product with WMO, num-threads4 and enable-testing. Consumer macOS15 imports that freshly emitted module and links that exact dylib through explicit I/L/l/rpath flags; it does not rebuild a substitute SwiftMechanics target. Pinned Swift6.4.0, native SwiftPM backend, jobs4, 900-second external process-group deadlines,8GiB private allocated-growth cap and4GiB global free floor define this cold route, separate from historical128MiB thin consumers. Two-second watcher and256MiB reaction margin bound resource observation. Root owns the cold lease; only preparation proceeded before release. Pre/post individual hashes bind all1995 producer Swift files, original fixture8 and actual emitted module/objects/library/link/runtime. Actual proof is limited to the completed route and selected independent oracles recorded below.

The first fresh consumer compile produced a pinned6.4.0 IRGen signal11 in the compiler-generated typed-error async reabstraction thunk for the explicit typed-throws Task closure. Producer1995 compiled successfully and remains unchanged. The causal Native adapter uses Task's actual untyped throwing closure boundary and preserves ModalReductionQualificationError through the existing explicit catch; unexpected errors still fail with an assertion. No physical input, oracle, tolerance, production API or supplier changes. The original failed log/source freeze is retained in the private failed-pass-1 directory. Fixture-only compilation resumes against the same matching producer.

The actual pinned Testing macros reject an @available15 suite and its inherited test availability even under the actual macOS15 consumer. The fixture-only correction removes that redundant suite annotation while the literal target remains15 and the real Mutex counter/public cases retain their available15 contract. This makes no macOS13 fixture claim. Private native consumer include flags use one joined `-I<absolute module directory>` token, preserving the same producer module; this avoids native generated-runner orphan include syntax diagnosed by the companion integration. Original compiler diagnostics are separately retained; physical cases remain unchanged.

Actual runtime exposed a fixture metadata arithmetic error: the seven selected identifier lengths sum to91, not101 (11+11+10+14+21+14+10); adding four node comparisons gives95 per admission. Correct exact oracles are total3762, supplier2827, zero-call prefix1734 and final64 rejection prefix3698. Storage2060 and all physical oracles/tolerances are unchanged. Original failed runtime receipt is preserved; this corrects the independent arithmetic prediction rather than weakening resource acceptance.

The first physical run preserved four passing cases and three RED cases. Actual operating shear .1 is explicitly retained as .structural(.nonsymmetric) refusal under the lower bit-exact pencil symmetry contract. The success witness uses lower-admissible dyadic operating shear .125 and increment .075, preserving the same final F=.2 and every stress/strain/energy oracle. This is a selected admissible-pencil proof, not general operating-state acceptance. No supplier symmetrization or tolerance adjustment occurs. The fixed failed-three cases are rechecked through the same public protocol first, with initial RED and passing-case evidence retained, then the seven Native tests and same six public cases establish the final fixture boundary.

### Selected fresh Native1995 evidence

The fresh route used committed HEAD `4ac336117d2a840ca79c344a62d79fd48ee6e9db` registered1983 plus current ModalReduction12, exactly1995. Every producer source, all1995 objects, three emitted module metadata, fresh dylib and original fixture8 source/object/link identities were bound before/after the final runtime. Producer macOS13 and fixture macOS15 are distinct. Final effective native driver jobs4/4 and WMO frontend threads4 were recorded; no old module/depot or Terrain18 was used.

| Evidence boundary | Actual result |
|---|---|
| Producer | Fresh dynamic1995 compiled86.154s; all1995 objects, module and library retained |
| Original physical stress | Current F=.2 shear, finite Green strain, actual P/S/Cauchy and original reference energy/force/moment/virtual power passed |
| Operating-source domain | Selected admissible operating.125 + increment.075 reaches same final F=.2; original operating.1 remains typed .structural(.nonsymmetric) |
| Work and cancellation | Actual3762 operations,2060 scalar units, one real material evaluate; exact failing prefixes, cooperative late publication cancellation and awaited Native Task passed |
| Stable failed boundary | Failed-three protocol recheck passed, original RED and four previously passing cases retained |
| Native/public | Seven actual Native cases passed; same synchronous public six lines matched exactly; public loader trace shows the expected fresh dylib path |
| Signatures | Library/public strict verification exited0; test-bundle strict verification exited1 with the retained resource-signature discrepancy, separate from runtime success |
| Resource envelope | Observed additional allocation937201664B (<8GiB), minimum free199745880064B (>4GiB), maximum watcher sample.601s;2s samples do not establish between-sample peaks |

Fresh [receipt](../../.build/af36-modal-native/native-qualification-receipt.json) SHA256 `0a1fa2f8f2a3ec4d415b96d1f5f4aaf874ab757680b19b122dceafb695c46985`; [producer inventory](../../.build/af36-modal-native/producer-output-inventory.json) SHA `093d16efc0f293eb25faeb2aa2ffc8271a10c3913a630ca06cc4c58644a8832b`; [fixture/link/actual-loader binding](../../.build/af36-modal-native/consumer-object-link-bindings.json) SHA `4f7a0f61353302ece672fd65a9fe23f3a05b06fbd8ae56395ddd589eab839a48`. Executed source freeze SHA `dea652944ebf9b9b22f59a06e68b4fd90c7daa7d93d94edc0c5b7e40e55f0e56`; source freeze is retained without rewriting executed provenance.

The selected stress operation has actual Native behavior evidence; this does not qualify general non-dyadic operating pencils, modal frequency/transient/truncation accuracy, arbitrary material/finite-rotation domains, ordinary/Embedded execution, performance or stack safety. Source/library were unchanged after initial emission. Fixture repairs only addressed actual compiler adapter constraints and independently corrected metadata arithmetic while retaining physical oracles/tolerances. Shared registration, parent progress and commit belong to root. Cold lease is released.

### Final registration comment delta
Root authorized removal of exactly two production comments whose sole outstanding condition was matching-source stress behavior proof. Existing seven Native/six public cases cover successful current-material response and original source/domain/work/legacy failure and cancellation behavior. No fixture Swift or production signature/arithmetic changed in this final delta. The prior Native1995 receipt binds pre-removal comment bytes; the registration source freeze retains per-file old/new identities. No compiler lease is used here. Root will rebuild/run the final union once before its feature commit. Shared Package/platform composition remains root-owned. The final HEAD-derived proposal registers literal Support6/Test1/Public1 with the ModalReduction DESIGN exclusion. The original macOS15 consumer proof remains separate; the subsequent guarded macOS13 union consumer must establish final registration bytes.

### Canonical availability and final union boundary
The root production library remains macOS13. The public entry point and unannotated Testing suite explicitly guard macOS15 before constructing the available15 case owner and real Synchronization.Mutex counter. An older macOS runtime throws `unsupportedOperatingSystem(requiredMacOSMajor: 15)` rather than silently skipping a case or replacing synchronization. Suite/Test annotations remain absent because the pinned Testing macros reject them. Other platforms retain the same API through the wildcard availability contract; this does not establish WASI runtime behavior. Physical inputs, all six synchronous oracles, awaited cancellation, and tolerances are unchanged.

The final private union fixes committed HEAD5d4e16e source2014 and adds only ParticleFlows18, SpatialProjection20, ModalReduction12, NonlinearEstimation18, LinearEstimation16, InertialParameters9 and PoseIK17, giving2124. Existing production exclusions, including Hydraulic registration, remain intact. Fresh dynamic producer macOS13 and a guarded consumer macOS13 (actual generated Testing deployment is recorded separately) replace the earlier macOS15-only composition. All source/module/object/library identities are checked before/after; other feature behavior is not inferred from compilation. Root owns shared registration and commits. The final union Native execution below completed under the granted cold lease; portability remains unverified.

### Final guarded Native2124 evidence
The fixed HEAD5d4e16e2014 plus exactly the selected110 owner-frozen sources compiled and linked in32.780s. All2124 Swift sources,2124 objects, three module metadata and the dynamic library were individually bound before/after. Fresh immutable producer outputs are reader-accessible; no old1995 module or unrelated live AF31 source was used. This compilation does not establish behavior of the six other added components.

| Boundary | Actual evidence |
|---|---|
| Deployment | Producer13; support/public13; actual generated Testing target14; case/counter execution guarded15 |
| Physical behavior | Original seven Native cases passed in.003s framework time (SwiftPM3.015s); exact six public lines passed in.284s |
| Final source delta | Two satisfied production marker comments removed; only error/Test/public fixture availability adapters changed; all physical inputs/oracles/tolerances retained |
| Original failures | Legacy ConstitutiveCallWork remains marked typed unsupported; source/domain/work/early/late/awaited cancellation oracles passed |
| Real producer linkage | Public loader traced the exact fresh union dylib; source/object/module/library hashes remained equal |
| Signature boundary | Library/public strict0; test-bundle strict1 retained resource-signature discrepancy, separate from physical runtime results |
| Resource samples | Maximum additional1048199168B (<8GiB); minimum global free181144772608B (>4GiB); max sample.111s,2s interval does not prove between-sample peaks |

[Final receipt](../../.build/af36-union-native/native-qualification-receipt.json) SHA `52b93dc8e3a16139117238c5391e0b46523f5a64a4b818f685ba2cb1e9ec60c1`; [source freeze](../../.build/af36-union-native/source-freeze.json) SHA `4bf78c90f1d92f6698680397a855d1f2ab1c07ba5798413b0229eb2246c48140`; [producer inventory](../../.build/af36-union-native/producer-output-inventory.json) SHA `12661799a67c417d3551f94f510c501a930610a5dcc5c95fdbb2c038d4fd25d9`. The final guarded fixture bytes and marker removal are covered by this receipt. Older macOS runtime rejection is a declared guard contract, not an exercised older-OS runtime claim; ordinary/Embedded and broader modal dynamics remain unverified. Root performs shared registration/commit. No compiler or cold lease remains active here.
