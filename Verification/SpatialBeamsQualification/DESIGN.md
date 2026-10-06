# Selected Spatial Beam Qualification

## Purpose and Scope
Parent: [SpatialBeams](../../Sources/SwiftMechanics/Physics/Flexible/SpatialBeams/DESIGN.md). No children. Own six immutable synchronous public physical cases and one Native awaited Task cancellation case through SpatialBeamAssembling and SpatialBeamEvaluating. Native2363 is historical preparation only. The fresh Root-granted AF38 common2270 producer supplies the selected Native evidence below.

## Responsibilities and Boundaries
Independently check the existing two-node12DOF linear EB/Timoshenko element. No solve/evolution, finite rotation, warping, resolved transverse/torsional stress, mesh convergence or CAD membership claim. Source25 changes require an actual counterexample and prior production DESIGN update, followed by freshly matching module and all changed component objects.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [SpatialBeams](../../Sources/SwiftMechanics/Physics/Flexible/SpatialBeams/DESIGN.md) | parent, depends on | Public assembly/response/field and original typed errors | Only selected linear domain |
| [Numerics](../../Sources/SwiftMechanics/Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalBudget/Work | Original prefix retained on failure |
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/Geometry/DESIGN.md) | depends on | Vector3/Matrix3 and finite tolerance | Explicit SI/engineering measures |

## Architecture
```text
Independent physical literals -> public beam/source/state -> actual assembler/evaluator
 -> analytic axial/torsion/cantilever/rigid kinetic oracle
 -> original field/balance/virtual-power check -> same six public cases
Native separately: actual Task cancel -> await original throwing operation
```

## Contracts and Invariants
Fix L2m, E1200Pa, G500Pa, rho3kg/m3, A0.02m2, Iy0.00002m4, Iz0.00004m4, J0.00003m4, ky0.8,kz0.6, cy=cz0.1m. EA24N, EIy0.024Nm2, EIz0.048Nm2, GJ0.015Nm2, Sy8N, Sz6N and total mass0.12kg. Supplied material/source/frame/node/revision values remain exact. Calibration is explicit caller input; no inferred section stress authority.

| Shared case | Independent original oracle |
|---|---|
| Axial/torsion | K pair EA/L and GJ/L; U=(EA du2+GJ dtheta2)/(2L); forces are positive gradient and restoring negatives |
| Bending/shear | Closed4x4 beam stiffness with phi=12EI/(SL2); tip force P1e-5 gives displacement PL3/(3EI)+PL/S and rotation PL2/(2EI); EB omits shear compliance; first gradient force minusP and moment minusPL in v/z plane, plusPL in w/y plane |
| Mass/damping | Axial/twist linear speed integral L(a2+ab+b2)/3; rigid transverse rotation integrates x2 as L3/3; endpoint quadrature is separately declared; C=0.2M+0.3K and dissipation original independent forms |
| Frame/field/power | Quarter-turn Z signed permutation, original fields at x0.5,y0.05,z0.04 with axial strain0.001, curvatureZ0.001, twist0.002; fiber strain0.00095/stress1.14Pa, energy per length0.000012054J/m; virtual work0.0192468 for declared arbitrary virtual nodal vector |
| Original refusals | Metadata/source identity, finite rotation, resolved stress, geometry/slenderness, envelope, location, nonfinite/overflow and original typed supplier failure |
| Work/cancel | Assembly storage2304/response4096, fixed charged operation counts plus actual metadata byte count, preserved exhausted prefix, early and last successful checkpoint cancellation |

Absolute oracle tolerance1e-12 plus relative1e-9 times magnitude is fixed before execution, including small nonzero energies. Full matrix/power/force checks use independent formulas, never producer internal interpolation/helpers. Symmetry and six rigid null modes are additional checks, not a substitute for physical literals. Consistent mass and endpoint mass remain distinct; mass-proportional damping can damp rigid modes. All four frame triples transform equally, preserving force/moment virtual work.

## Runtime Flows
Create actual source/material/section -> assemble through protocol -> independent physical state -> evaluate/field through protocol -> typed assertions. Each operation has an exclusive NumericalWork. Shared six cases use the same protocol in Swift Testing and standalone. Native cancellation captures immutable admitted inputs, cancels the actual Task and awaits the same public evaluator with Task.isCancelled admission.

## State, Ownership, and Lifecycle
Definitions/assemblies/fixtures are immutable Sendable values; work and oracle arrays are operation-local. One callback checkpoint counter owns Mutex<Int> with identical storage, reads and mutation on Native/WASM/Embedded. Counter and consuming fixture entry points explicitly require macOS15, matching the actual SDK API. No callback/I/O/await executes under its lock. No target changes Sendable or substitutes raw mutable state. Each independent test owns its own counter.

## Failure, Concurrency, and Constraints
Typed qualification errors wrap original CoreError/ModelError/NumericalError/SpatialBeamError without cast or success fallback. Bounded fixture loops traverse12/144 scalar entries and a finite declared set of fields; no fuzz/profile/solver. The earlier2363/128MiB thin preparation is historical and was not reused. The AF38 fresh common Native contract below owns actual source/object/module/dylib binding, consumer resources and deadlines. Root owns execution leases; no full producer or object copy is performed by this reader.

## Verification and Change Impact
Six fixed synchronous cases plus Native awaited cancellation test are the completion evidence. Original25/component supplier source matches are prerequisites. The AF38 evidence below qualifies the selected fresh Native graph only; ordinary/Embedded and broader domains remain outside this proof. A concrete original physics failure cannot be repaired by changing oracle/tolerance/index/domain or mixing old objects with new source; update owning DESIGN and obtain matched producer first.

## AF38 Fresh Common Native Contract

Root supplies the frozen common producer derived from committed f0325b0 and the seven admitted cohorts. This owner reads its exact2124 baseline plus admitted cohorts source/object/module/dylib receipt; it never recompiles or copies producer objects. The old2363 producer and thin128MiB contract above are historical preparation only and cannot qualify this fresh run.

Support and Public compile for macOS13. Testing uses its actual macOS14 boundary. The real Mutex counter and case implementation retain macOS15 availability. Each public/test body enters that implementation only inside `#available(macOS 15.0, *)`; unsupported Native versions throw `SpatialBeamsQualificationError.unsupportedNativePlatform` instead of succeeding, skipping, substituting raw state or removing synchronization. Suite/Test macros and the executable type carry no availability annotation. Native Task cancellation remains one actual self-cancelled child whose original evaluator call is awaited.

The consumer owns at most1GiB allocated growth from one immutable baseline, requires4GiB global free space, samples every2s with a maximum5s reliable observation gap, uses Native SwiftPM and compiler jobs4, joined absolute module `-I`, and process-group deadlines900s setup,180s tests and240s public. The original six physical cases and seventh awaited cancellation test retain their coefficients, tolerances and work/refusal oracles. Exact common sources/objects/modules/library and all eight fixtures are verified before and after execution. Root owns shared registration/index/plan/progress/Git. Ordinary/Embedded and full stress/finite-rotation claims remain outside this evidence.

### Causal Typed-Throws Fixture Repair
The first fresh consumer compiler rejects the source/location assertion's throwing `&&` right-hand autoclosure because it widens the original qualification error to `any Error`. The fixture preserves the original source identity short-circuit and label, then obtains the same original typed location, then checks the same location equality. No physics, tolerance, work or accepted result changes; no cast/error suppression is introduced. The failed compiler receipt is retained, and consumer continuation uses the original allocation baseline and read-only common producer.

## AF38 Actual Native Evidence

The actual common2270 Native source/object/module/dynamic library authority is `.build/af38-next-native/handoff.json`, SHA-256 `01e2ca4119bd0397a6f877d53f5a07955d3b4c00acdda4c94d33fbb752b097f1`. Original25 production Swift files were unchanged. The first consumer compile exposed only the fixture typedthrows `&&` error described above; its original failure receipt/log/freeze remain under `.build/af38-spatialbeams/failed-fixture-typedthrows`. No production/supplier or physical-oracle change was needed.

The consumer continued the same immutable allocation baseline. Original seven tests and six public physical groups passed; the seventh test cancels a real child Task and awaits the original public evaluator refusal. Native continuation receipt `.build/af38-spatialbeams/native-continuation-receipt.json` has SHA-256 `a9fc0216fca7c4ed56ea882146f5b56586d0bee384b913d2a3c8b394d4c3ea8e`. Consumer continuation build4.129911708s, tests10.494411833s and public2.201059667s passed. Maximum new allocation71,471,104 bytes and minimum observed free169,754,296,320 bytes met the same1GiB/free4GiB contract.

Actual Support/Public compile target is arm64-apple-macosx13.0, and actual Testing target is arm64-apple-macosx14.0. Public dyld output proves loading the exact common dynamic library. SwiftPM's test helper emitted no equivalent dyld trace; the executed test binary dependency/rpath is retained rather than inventing a runtime trace. All common sources/objects/three metadata/library and all8 fixture source copies matched before and after the actual run. These compile targets do not claim runtime execution on older macOS versions. Root owns canonical registration and coherent commit; portable profiles, full stress, finite rotation and coupled evolution remain open.
