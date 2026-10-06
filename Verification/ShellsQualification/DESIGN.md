# Selected Flat Q4 Shell Qualification

## Purpose and Scope
Parent: [Shells](../../Sources/SwiftMechanics/Physics/Flexible/Shells/DESIGN.md). No children. Own six synchronous independent public cases and a Native awaited cancellation seventh for the existing rectangular infinitesimal MITC4 shell. The eleven original shell sources use a freshly matched common producer with committed `d30b585` lower suppliers; historical2363 objects are not current evidence. Preparation does not prove behavior. Root grants Native execution and owns shared registration/Git.

## Responsibilities and Boundaries
Verify plane-stress membrane, constant-curvature MITC4 bending, tied shear, force/energy/tangent, translational/rotary mass, Rayleigh damping, six infinitesimal rigid modes and exact source/domain/work failure. No curved/distorted reference cells, nonlinear/finite rotation, drilling DOF, external load, runtime solve, CAD authority or convergence family is added.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Shells](../../Sources/SwiftMechanics/Physics/Flexible/Shells/DESIGN.md) | parent, depends on | ShellAssembling, plate/state/admission/result | Local fiveDOF coordinates, positive energy gradient |
| [Elasticity](../../Sources/SwiftMechanics/Physics/Materials/Elasticity/DESIGN.md) | depends on | IsotropicElasticity/SymmetricTensor tangent | Actual plane-stress law is retained |
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/Geometry/DESIGN.md) | depends on | Vector3 and finite reference basis | Explicit reference embedding, no raw spatial DOF reinterpretation |
| [Numerics](../../Sources/SwiftMechanics/Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | NumericalWork/Budget | Original spent prefix/storage retained |

## Architecture
```text
Independent rectangular physical fields and closed plane-stress constants
 -> public plate/state/admission -> original Q4 MITC4 assembler
 -> literal energy/force/mass/physical-wrench oracle
 -> same six synchronous public cases
Native: actual Task cancellation -> await original shell operation
```

## Contracts and Invariants
Fix width2m,height3m,area6m2,h0.2m,rho5kg/m3,K320/3Pa,mu40Pa,lambda80Pa. Condensed plane stress C11=120Pa,C12=40Pa,C33=40Pa. Membrane scale h, bending h3/12=1/1500m3 and shear scale kappa*mu*h=6N/m with kappa0.75. Total translational mass6kg and each director rotary inertia0.02kgm2. Four nodes are row-major (0,0),(2,0),(0,3),(2,3). Coordinates are [u,v,w,betaX,betaY], with physical angular-rate components (-betaYdot,betaXdot,0). Positive returned internalForce/dampingForce are energy-gradient/Cv covectors; physical restoring/damping forces are their negatives.

| Shared case | Independent physical oracle |
|---|---|
| Membrane | u=.001x+.0015y,v=.0015x+.002y; strain(.001,.002,.003), resultants(.04,.056,.024), energy0.000672J; endpoint gradient from integrated shape derivatives +/-height/2 and +/-width/2 |
| Bending/shear | betaX=.001x+.0015y,betaY=.0015x+.002y,w=-.0005x2-.001y2-.0015xy; tied shear0, energy0.00000224J independent of uniform subdivisions; exact h3 scaling. Pure gamma(.001,.002) energy0.00009J and conjugate w/beta forces |
| Mass/damping | Exact Q4 scalar consistent mass: total/36 times tensor-product4/2/1 corner weights; row-sum total/4. Velocity w=x+y gives vMv44 consistent and57 lumped. Uniform velocity(.01,.02,-.03,.04,-.05), alpha.2,beta.3 yields mass quadratic0.008482 and power0.0459764W |
| Rigid/frame/power | Six explicit infinitesimal rigid fields, local operators invariant under embedding basis e1=worldY,e2=worldZ,n=worldX; physical force/moment sum and dot-power via original local-to-world basis. Independent membrane virtual strain(.004,.003,.001) gives work0.002112 |
| Refusals | Original finite-rotation, stale identity/revision/provenance/frame, invalid layout/basis/input, inverted in-plane Jacobian, corner linear envelope, overflow/underflow, original Core/Material/Numerical failure |
| Work/cancel | Single20DOF storage1536scalars; consistent charged operations2*metadata+133796, lumped adds480. Under-cap spent prefixes and last successful checkpoint cancellation preserve failure atomicity |

Fix oracle tolerance1e-12 absolute plus1e-9 relative magnitude before execution. Independent energy and nodal traction formulas distinguish the original algorithm from a mirrored implementation. Kq and directional energy/tangent relations are supplementary checks; nonzero analytic force/energy/mass witnesses establish physical behavior. No nodal stress is invented. Raw corner shear is a domain guard, distinct from tied shear energy. Basis embedding changes world positions/force interpretation, while local DOFs/operators remain local.

## Runtime Flows
Construct public physical plate/state -> actual ShellAssembling -> independent analytic acceptance -> same public case API for standalone and Swift Testing. NumericalWork is per operation. Actual native Task cancellation uses admitted immutable inputs, self-cancels and awaits the original producer; synchronous early/late callback cancellation uses separate operation-owned counters.

## State, Ownership, and Lifecycle
All producer values and public fixture suite are immutable Sendable. Oracle arrays and work are local. Shared checkpoint counter uses common Synchronization.Mutex<Int> and withLock with no callback/I/O/await under lock; no Embedded raw-state substitution. The counter and case implementation require macOS15 because the actual Mutex API does. Support/Public compile at macOS13 and Testing at macOS14. Test and public entry bodies check macOS15 before constructing the case implementation; unsupported runtimes throw `ShellsQualificationError.unsupportedNativePlatform`. Suite and executable declarations carry no macro-incompatible availability annotation. This preserves the same Mutex storage and actual operation, without a raw-state substitute. Each test owns its own counter and has no shared mutable fixture/global filesystem.

## Failure, Concurrency, and Constraints
Typed fixture errors retain original ShellError/CoreError/ModelError/MaterialError/NumericalError. All fixture loops have fixed grids<=3x2, <=60DOF and dense<=3600 entries, declared bounded work/storage. Source/fixture preparation creates no object/module copies. The fresh fixture-only consumer directly reads Root's immutable common module/dylib and its source/object inventory. Native jobs4 with pinned Swift6.4.0 and process-group deadlines300s bound each setup/test/public operation. A single immutable allocation baseline includes the private consumer, proofs and temporary files; additional allocation is capped at1GiB, global free capacity stays at least4GiB, sampled every2s with observations at most5s apart. Root's matched producer handoff and lease precede compiler execution. Strict signatures remain separate from physical results.

## Verification and Change Impact
Completion requires actual attributable seven Native tests and the same six public cases against matching eleven sources and consumed supplier paths, all source/object/module/library bindings before and after, unchanged original physical oracles and explicit target13 producer/Support/Public plus target14 Testing with checked macOS15 helpers. The AF42 selected Native execution satisfies that condition. Ordinary/Embedded, broader root graph and convergence remain separate.

The material-failure witness is the actual IsotropicElasticity input constructor rejection before a valid plate can exist; it does not claim an injected invalid elasticity or a reachable failure of the admitted shell tangent. Two comment-only marker deltas are fixed in `incomplete-marker-delta.json`, preserving original11 before-marker files. The fresh AF42 producer inventory binds the current marker-bearing eleven sources; historical2363 is not used or silently labeled current.

### AF42 source-first closure
The source review finds no selected-domain operator defect. The concrete fixture availability defect is repaired before execution: retain the real macOS15 case/counter implementation, remove declaration-level Suite/main availability and guard actual entry bodies. Below macOS15, typed unsupported failure is required rather than an empty successful case. This changes no original physical value, acceptance tolerance, work-prefix expectation or cancellation oracle. Original fixture/source/doc bytes are retained privately before the change. Completion requires the same six public physical cases plus one awaited native Task cancellation, with fresh common producer/source/object/module/library bindings verified before and after. Portable behavior, finite motion, curved shells and drape remain separate.

### AF42 actual Native receipt
Private evidence root: `.build/af42-shells`. Formal common authority is `.build/af42-next-native/attempt-2/handoff.json`, SHA256 `f6c4959f204ce51cb07259224891546bd4d18847d397d9a6731d68095ae77941`; exact2387 sources, fresh matching committed lower suppliers. Native receipt `native-receipt.json`, SHA256 `9868347a36f3f57babc89e312ed19fd3eb6193d53b91056fb4c455aad00f1801`, records seven Swift Testing cases and six public cases GREEN once. Fixture-only setup8.065s, test6.139s and public2.063s passed with pinned Swift6.4.0, actual jobs4 and300s deadlines. Maximum additional allocation68,214,784bytes and minimum global free165,747,978,240bytes satisfy the fixed1GiB/4GiB contract.

Prepared binding verifies all2387 production source hashes, actual producer objects and three module metadata files, direct common dylib and unchanged fixture bytes before and after. Original shell production inventory SHA256 `8b7a6c7a85f60e2680a88c56955302a578b4670a8d7cab01627030a135f65aee` remains unchanged. The consumed dylib SHA256 is `c1016d2bfb18800d7ec0a242d0d606ff5f06b3b9afbef23e190b8f0fda990ad5`. Actual consumer compile commands bind Support/Public macOS13 and Testing macOS14. Public dyld trace establishes loading the exact common dylib; the test helper exposes no dyld trace, so test evidence uses its actual link/rpath plus immutable output binding rather than claiming observed loader trace. No production object/module/source copy or rebuild occurred. Original independent forces/energy/mass/damping/frame/power and numerical work/error/cancellation expectations are unchanged. Native runtime success does not establish execution on macOS13/14 below the guarded macOS15 helper boundary or portable targets.
