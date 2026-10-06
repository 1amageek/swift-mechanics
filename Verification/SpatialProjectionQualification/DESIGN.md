# SpatialProjectionQualification

## Purpose and Scope
Parent: [package](../../DESIGN.md). Children: none. Own selected independent periodic3D MAC projection/evolution evidence for [SpatialProjection](../../Sources/SwiftMechanics/Physics/Fluids/SpatialProjection/DESIGN.md). Selected fresh Native qualification is recorded below; root owns graph, matching producer leases, canonical registration and portable integration.

## Responsibilities and Boundaries
Use real SpatialFlowOperating/SpatialPressureSolving requirements. Independently construct three-dimensional potential plus divergence-free face fields, coordinate-loop Laplacian/gradient/divergence and finite-volume momentum/work witnesses. No planar supplier, walls, free surface, hydrostatic gradient, continuum convergence, turbulence or Runtime acceptance is inferred.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [SpatialProjection](../../Sources/SwiftMechanics/Physics/Fluids/SpatialProjection/DESIGN.md) | used by | Public project/step and original CG pressure solve | Changed supplier requires matching new source/object/module |
| [Numerics](../../Sources/SwiftMechanics/Mathematics/Numerics/DESIGN.md) | depends on | Original tolerance and cumulative work budget | Count oracle comes from exact primitive/phase sums |
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/DESIGN.md) | depends on | Frame ID / finite values | All grids are declared inertial Cartesian SI |

## Architecture
```text
original3D potential + solenoidal face fields -> independent coordinate stencils
                   |                                      |
                   v                                      v
actual matrix-free CG -> project/step -> full-cell physical oracle / energy / momentum
                   |                                      |
                   +--- supplier/refusal/work/cancel -------+
```

## Contracts and Invariants
| Shared case | Fixed independent evidence |
|---|---|
| potentialSolenoidalProjection | Nonplanar potential and all3 solenoidal components, anisotropic4x3x5 grid, mean gauge, every cell original pressure/divergence/correction, mass/momentum/energy |
| originalPressureEquation | Direct true matrix-free solve of independently constructed full3D RHS; incompatible constant RHS typed rejection |
| thirdAxisShear | u(z) and separately w(y), exact one-mode Euler viscosity amplitude, positive loss and explicit injection |
| donorMomentumEnergy | Fully3D solenoidal cross-axis field, independent conservative flux/predictor, all-cell force/RHS, donor/viscous work and source/energy closure |
| uniformSourceEvolution | All3 held accelerations, exact uniform velocity, original mass/momentum/energy, time/sequence advance and project-only authority |
| domainAndSupplierRefusals | Geometry/count/state/source/step/CFL/sequence failures, false pressure/shape/budget/throwing supplier refused by original checks |
| workAndCancellation | ZeroRHS independent65N+2 pressure work and374N+45 projection work,6N/20N storage, one-less and pre-initialization refusal; pre/during/final-publication callback cancel |
| NativeTaskCancellation (test only) | Actual self-cancelled Task calls production operation, typed cancel and unchanged known work/input |

Fixed scalar comparison absolute2e-9 plus relative2e-9*abs(expected). Original production physical bounds are gauge1e-9Pa, divergence1e-9/s, pressure absolute1e-8Pa/m² relative1e-10, force absolute1e-8N relative1e-10 and energy absolute1e-8J relative1e-10. Original linear tolerance absolute1e-10/relative1e-12/pivot0. These values are fixed before execution; source repair does not change them. Small grids are at most60cells; independent coordinate stencils never call internal spatial kernels or reuse production pressure as the analytic expected solution.

## Runtime Flows
Seven shared synchronous public cases are unchanged between Swift Testing and standalone. Native adds real awaited Task cancellation. Final callback-cancel is injected at the documented last pressure-publication checkpoint, before return and without a successful fallback. Custom fault suppliers return deliberately invalid originals through the actual requirement, never fake a successful physical oracle.

## State, Ownership, and Lifecycle
Inputs/state/results are immutable values; arrays/oracles/work are local. Callback observation uses one immutable Sendable owner containing Mutex<Int>, same declaration/access on Native/WASM/Embedded. That test-only counter and sole synchronous callback case require macOS15; production remains macOS13. No external callback/await/I/O occurs inside the counter lock; only the local increment/comparison does. Task cancellation uses actual Task state.

## Failure, Concurrency, and Constraints
Typed assertion and unexpected success failures distinguish fixture defects from production errors. Throws from the supplier preserve explicit failedSupplierWorkUnavailable=true; known caller resource failures retainfalse and actual work prefix. Existing historical2363 compiler evidence cannot qualify the new MatrixFreeSpatialPressureSolver raw bytes. No compiler/cache copies until root grants matching producer/consumer resource lease. Prepared Native envelope128MiB growth/112stop,768floor/784stop/896admission,2s/max5s watcher; deadlines are explicit in the eventual runner.

## Verification and Change Impact
Initial source-first evidence had no behavioral execution. Current causal production change fixes uncharged/unpolled initial CG and direction-copy paths, with checked4N initialization allocation/COW bound,4/cell original RHS scan and1/cell direction assignment plus final publication poll. The exact zeroRHS supplier charge sum is4N+4N+(2N+1)+N+2N+24N+N+(2N+1)+24N+N=65N+2; complete caller projection adds own309N+43 to give374N+45, with peak20N. This independent sum and exact zero iteration return must be witnessed before success. No observed counts are substituted for expected values. Any future concrete numerical counterexample is recorded before DESIGN-first owning repair; original fixtures/tolerances/stack and domain stay fixed. Root owns parent/shared docs/Package/PROGRESS/Git and full integration.

### Fresh Native source closure attempt
The AF36 Native attempt uses committed4ac336117d2a840ca79c344a62d79fd48ee6e9db registered1983 sources plus exactly the current20 SpatialProjection sources, exported through git archive and privately frozen. Historical2363 objects/modules are absent and are not borrowed. A fresh dynamic SwiftMechanics producer retains macOS13, pinned Swift6.4.0, the effective HEAD exclusion contract, WMO, four frontend threads, testing enabled and actual driver jobs4. The separate fixture consumer uses that same fresh module/library and macOS15 for the unchanged common Mutex counter. Native eight tests and seven public cases preserve every original numerical oracle, physical tolerance and primitive work sum.

This cold attempt has a separate single allocation baseline: at most8GiB new generated storage and at least4GiB global free space, with256MiB reaction margin,2s sampling and process-group deadlines900s producer/180s consumer build/60s runtime. It is not evidence for the historical thin128MiB consumer envelope. Source/fixture hashes, actual emitted source/object/module/link bindings and resource receipts are recorded before and after execution in the private AF36 owner. Compiler/physical failures retain their first receipts and permit only causal owning correction; no fallback or relaxed oracle is introduced.

### Executed AF36 Native evidence
The fresh2003 producer compile/link exited0 in106.739s; fixture compile/link exited0 in21.468s. Eight tests passed (Swift Testing reports.007s suite; bounded test process5.344s), and the same seven standalone public cases passed (bounded process1.246s). No production or fixture Swift repair, formula change or tolerance adjustment was required. Source and all2003 objects/three module metadata/library plus all7 fixture objects were rechecked after runtime.

[native-final-receipt.json](../../.build/af36-spatial-native/native-final-receipt.json) SHA25616605f58ee60b36ff0d89593f160351344e660b73b1e6fae59f5ca354ed65921 binds execution freeze8ada7283480168cee4306e3b7a6aa38c1d94dadf706e7356143ca642d453e1c4. Dynamic library SHA2568633b18f8530eaa9408dfe2dd4af6c677dd62fbcc5198ffa12c40b6a67423abb and module SHA256204fa805b1de927e137a8f8e1d21a50f70cdca5e277feeea017c33e4e9b158e1 were unchanged. The single cold baseline ended with981688320B growth, below8GiB, and199760703488B free, above4GiB; this is not a thin128MiB proof. Native backend deprecation warnings are retained. One artifact collector initially applied WMO/testing checks to the link-only driver; its first failure is preserved and collection was corrected against the actual commands without another producer build. Ordinary/Embedded and canonical registration remain unexecuted by this owner.

### Committed Terrain union and availability preparation
The next registration proof derives its immutable production graph from committed5d4e16e4b38b556a957a5059c1fcc999f43c8d83 and its original Package exclusions:2014 registered Swift files, including HydraulicElements13, plus SpatialProjection20=2034. The earlier2003 selected proof does not cover this union. The shared candidate preserves the macOS13 package baseline; Swift Testing may raise its emitted test minimum to14. Mutex remains the same macOS15-qualified counter on every target. The public entry and work test use body-level #available(macOS15,*) guards and throw unsupportedOperatingSystem below15. No Suite/Test availability annotation or raw/no-op counter is substituted. The macOS15-qualified work function, complete physical oracles, fixed numerical tolerances and production20 bytes remain unchanged. Fresh union compilation, eight actual tests and seven public cases will bind these adjusted fixture bytes before registration. Root owns the shared candidate and commit; this paragraph records preparation, not execution success.

### Committed registration-union Native evidence
The immutable archive of5d4e16e4b38b556a957a5059c1fcc999f43c8d83 contributes all2014 registered source files, including HydraulicElements13. Exactly20 unchanged SpatialProjection files produce2034. The private registration producer passed fresh compile/dynamic link in32.042s with macOS13, pinned Swift6.4.0, Native SwiftPM, actual-j4 and WMO4/testing; the consumer passed compile/link in5.923s. Its Support/public compile target is13, the owned Swift Testing target is14, and the guarded work case executed on the current macOS15-or-newer runtime using the unchanged Mutex implementation. All eight actual tests passed (suite0.003s; bounded process1.417s), and the same seven public cases passed in0.483s. The availability-only entry/test/error changes do not alter four numeric/counter/fault support files, production20, fixed oracles or tolerances. No producer or consumer was rebuilt after successful compilation.

The [registration receipt](../../.build/af36-spatial-registration/native-final-receipt.json) SHA2560606d9893edcfab1cd8d66bcf5d0454a4540c6095f4e933770859182c55ee74e binds execution freeze3fb5e100f9ce454381e7a1aa0fa9634c704099e5e0edcfa4c63e8cc65e3ec97a. Stable SwiftPM sources/description, the actual complete emit-module source argv and every output-map source/object binding independently prove2034 closure; discarded temporary driver filelists are a retained limitation. Module, dylib, test/public image links and post-runtime sources/objects remain bound in private receipts. One collector misclassified link-only/generated-runner targets, was corrected from actual commands and collected the same successful outputs; first failure is retained without a compile rerun. The single cold baseline ended with1033601024B growth and182432804864B free, within8GiB growth/4GiB free. This is not a thin128MiB proof. This paragraph records private registration-union behavior; root owns shared manifest/index/commit, and ordinary/Embedded/full-fluid/Runtime admission remain outside its evidence. Documentation is appended after the execution freeze and has a separate final freeze.
