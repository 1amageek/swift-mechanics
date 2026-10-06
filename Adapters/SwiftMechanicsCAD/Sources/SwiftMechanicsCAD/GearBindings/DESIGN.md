# Gear bindings

## Purpose and Scope
Parent [SwiftMechanicsCAD module](../DESIGN.md); no production children. Own explicit source-bound binding of two admitted CAD involute-gear occurrences to actual compiled scalar shaft joints, with selected ideal external-spur fidelity. CA-007 motion/load evidence composes existing compiler, Joints, transmission and constrained-dynamics producers. This contract does not certify resolved tooth contact, bearings, CAD-derived inertia or complete CAD state migration.

## Responsibilities and Boundaries
CAD owns exact evaluated geometry and resolved unit-aware shape parameters. [GeometryAdmission](../GeometryAdmission/DESIGN.md) issues sealed original gear witnesses and stable-anchor queries. Caller owns compiled mechanics bodies/shafts, supplied inertia, initial physical recipe, coordinate layout, explicit mounting and transmission phase, domains, fidelity and numerical tolerances. This component verifies their association, then invokes actual AffineTransmissionCompiler and issues immutable CADGearPairBinding through an issuer-file fileprivate token. No public raw prepared constructor or same-module unchecked authority exists.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Optional Native adapter graph | Module composition | Root owns its index |
| [GeometryAdmission](../GeometryAdmission/DESIGN.md) | depends on | Sealed source-bound original gear/anchor queries | CAD source authority | Full identity and full geometry signature precede selection |
| [Compiler](../../../../../Sources/SwiftMechanics/Modeling/Compiler/DESIGN.md) | depends on | CompiledMechanicalModel and admitted state/evaluation | Mechanics generation authority | Actual compiled tree/frame/ranges are consumed |
| [Joints](../../../../../Sources/SwiftMechanics/Modeling/Joints/DESIGN.md) | depends on | Actual joint/body motion and root convention | Shaft-frame authority | Selected fixed-root spatial scalar chart |
| [IdealNetworks](../../../../../Sources/SwiftMechanics/Physics/Transmissions/IdealNetworks/DESIGN.md) | depends on | Original signed row/effort/power acceptance | Selected TR-001/008 fidelity | Ideal rows do not certify tooth or bearing loads |
| [ConstrainedDynamics](../../../../../Sources/SwiftMechanics/Physics/Mechanisms/ConstrainedDynamics/DESIGN.md) | depends on | Original physical solve and transmission diagnostics | Independent solved load evidence | Geometric assembly multipliers are not forces |
| [Gear tests](../../../Tests/SwiftMechanicsCADTests/GearBindings/DESIGN.md) | used by | Original public geometry-to-motion/load proof | Owner proof | Pinned Native only |

## Architecture
```text
sealed CAD geometry -> original SI gear witness + stable end-face anchor
actual compiled model/state -> original world parent-anchor/body pose + q/v ranges
caller mounting phase/fidelity/layout/domain -> association and original phase checks
 -> actual AffineTransmissionCompiler -> sealed CADGearPairBinding
 -> original Joints/constraint evaluation/rigid equations/mass-weighted solve
 -> original TR effort diagnostics + independent motion/load/power oracle
```

## Contracts and Invariants
Public interface is CADGearBindingPreparing.bind(_:geometry:model:state:layout:policy:transmissionPolicy:work:transmissionWork:) throws(CADGearBindingError) -> CADGearPairBinding; ReferenceCADGearBindingPreparer is the fixed builtin implementation. CADGearPairRequest carries expected CADSourceIdentity/ModelStamp, two CADGearShaftRequest values, explicit phase/phaseScale, network/relation IDs, coordinate/time domains and fidelity. The constructor label freshSource explicitly declares fresh mechanics initialization. Each shaft request declares occurrence ID, actual joint ID, stable shaft-end-face anchor and finite mounting phase in radians. CADGearBindingPolicy owns finite length, angular/axis and module/pressure compatibility tolerances plus bounded model/metadata visits; values are caller policy, not universal physical constants.

CADInvoluteGearQuerying is a dedicated refinement with a required involuteGear operation; existing CADGeometryQuerying requirements remain unchanged. Binding consumes the actual sealed CADGeometryAdmission and actual CompiledMechanicalModel/CompiledKinematicState. Expected source identity is checked before original stable selection. Expected model identity/revision and initial state association are checked through original compiled authority. Selected models have spatial fixed root, fixed root authority, no prescribed anchors, scalar dynamic revolute-Z shaft joints mounted to that root, and a scalar q/v chart. Occurrence body/frame must match the actual selected child body/frame; occurrence placement must agree with its original initial world pose. Actual tree layout supplies joint position/velocity offsets; corresponding supplied layout coordinate IDs, angle dimension and revision must agree. Common transmission reference is the actual tree world frame, not the occurrence frame ID.

The original source gear origin, local +Z extrusion axis and local +X tooth-zero direction are mapped by admitted occurrence placement. The actual shaft parent-anchor transform and original manifold axis determine port jointToReference/axis. CAD +Z must align with that shaft's positive axis, source origin must lie on the shaft axis, and a resolved end-face anchor must belong to that occurrence and align with the same line/normal. Caller mounting phase is checked by comparing source +X with parent-anchor rotation applied to Rz(q+mountingPhase)*unitX. This preserves actual nonidentity root/anchors and unwrapped caller q phase; no global modulo law or inferred engagement state is added.

Both gears must be genuine source gears, with positive exact-convertible UInt32 teeth, zero twist and no double-helical declaration for this selected fidelity. The original resolved pitch radii/tooth counts establish equal module, base/pitch ratios establish compatible pressure geometry, projected center spacing equals the sum of pitch radii, and axial sweep spans overlap. These are proposed ideal transmission input checks, not tooth contact/refinement or bearing-force evidence. CAD profile/sweep error declarations remain attached provenance and never become a mechanics contact-error guarantee.

Only explicit idealExternalSpur fidelity succeeds. A caller-requested toothResolved path has an INCOMPLETE_IMPLEMENTATION marker and typed unsupportedFidelity failure; it never falls back to the ideal row. Helical/twisted source is refused for this ideal domain. Caller declares transmission phase in radians with positive phaseScale. The original signed phase row N1*q1+s*N2*q2-phase=0 must accept the actual initial q under caller tolerance. Original AffineTransmissionCompiler remains the coefficient/normalized chart issuer and preserves signed parallel-axis orientation. No CAD datum is invented as a shaft ID, layout ID, law phase, contact force or inertia.

Prepared binding retains original CAD identity/occurrences/gear witnesses/anchor association, actual compiled mechanics model and its stamp, chosen phases/fidelity and original compiled transmission network. It supplies no unchecked Runtime publication or physical-force acceptance. Caller force/motion solve uses the retained actual model and original network; true load evidence is the original mass-weighted reaction followed by AffineMechanismTransmissionDiagnostics, not an invented or geometric KKT multiplier.

Source edits require fresh exact evaluation and explicit fresh mechanics initialization. Old source/anchor or model bindings fail rather than silently rebind. Compatible Runtime physical-state migration, proxy rebuilding and CAD-derived full moments remain separate owner gaps; no migration success API is declared. exactMassProperties retains the original explicit typed refusal.

## Runtime Flows
Caller owns source/model preparation; binder preflights its own fixed pair, model records and metadata bounds, validates fresh initial association, invokes original queries/evaluation/compile once and polls cancellation before issuance. Each failure stops without fallback/retry. Later motion/load operations use original producers and their numerical/physical acceptance rather than a duplicated gear algorithm.

## State, Ownership, and Lifecycle
All prepared data is immutable Sendable owned backing. Gear query and pair binding tokens have explicit fileprivate initializers in their actual issuing files, are not exposed by results, and have no synthesized raw initializer bypass. Work is exclusive inout local state; there is no cache, global registry, mutable initialized flag, unchecked Sendable or target-specific state. Caller-controlled source/model owner lifetime remains retained by the immutable prepared binding.

## Failure, Concurrency, and Constraints
CADGearBindingError distinguishes stale source/model, missing/duplicate shaft/occurrence, wrong anchor, incompatible dimensions/placement/axis/module/pressure/phase, unsupported fidelity/domain, capacity and cancellation; nested original CAD/compiler/joint/transmission failures remain typed. Adapter-owned record/string visits and storage are bounded before owned growth; original CAD/compiled Joints evaluation cost is not fabricated as adapter work. Original NumericalWork retains its actual transmission prefix on failure. Root's finite runtime/setup limits constrain execution; unknown supplier work stays unknown.

## Verification and Change Impact
Dedicated public tests evaluate two actual pinned CAD gears, bind actual compiled shafts, verify resolved SI parameters through parameter references/mm/degree sources, nonidentity root/anchors and mounting phases, actual Joints q/v motion, and original constrained-force/shaft-torque/power results against independent rotor inertias and drive. Separate repeated occurrences preserve distinct mechanics bodies/frames. Refusal tests cover stale full identity, same-kind edited/deleted/cross-body anchors, wrong shaft/frame/range, incompatible module/axis/center/phase, requested resolved/helical fidelity, capacity/cancellation and fresh source/reinitialization. Exact moments remain typed refusal. Root owns indexes/manifests/public fixture/integration; independent owner Native proof uses immutable3fe26e1 and stopped shared private CAD cache only after confirmation.


The selected owner Native behavior is qualified by the [executed test evidence](../../../Tests/SwiftMechanicsCADTests/GearBindings/DESIGN.md#af29-executed-owner-evidence). Actual original CAD issuance, SI queries, compiled-shaft association and mass-weighted motion/load/power plus typed refusals are exercised. Swift source/tests are frozen at the recorded13-file digest; Native proof does not qualify tooth-resolved fidelity, CAD-derived full moments or other adapter platforms.
