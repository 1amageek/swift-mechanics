# Geometry admission

## Purpose and Scope
Parent [module](../DESIGN.md); no children. Own the selected builtin exact geometry admission, source identity, explicit repeated occurrences and source-bound surface/edge/volume queries. Independent primitive and involute-gear source features are supported; other feature graphs are refused before evaluation. This selected domain is not general CAD mechanical input completion.

## Responsibilities and Boundaries
Only ReferenceCADGeometryAdmitter invokes original DocumentEvaluator.evaluateExact and issues immutable CADGeometryAdmission through an admission token whose initializer is fileprivate in that issuer file. A public raw EvaluatedDocument constructor is never accepted as authority. CAD supplies exact BRep and query semantics; mechanics supplies safe SI frame transforms. Caller supplies unique occurrence/body/frame identifiers, source feature selection, rigid placement and explicit validated material density.

## Related Designs
| Design | Relationship | Contract used | Summary | Caution |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Public adapter boundary | Module composition | Native only |
| [CADKernel pin](https://github.com/1amageek/swift-CAD/tree/295a724cdf0219c904007c2735f2b99ef08200ca/Sources/CADKernel) | depends on | Builtin exact evaluator, edge/surface queries | Original geometry issuer | Deferred exact results do not support cache-based generic validation |
| [CADTopology pin](https://github.com/1amageek/swift-CAD/tree/295a724cdf0219c904007c2735f2b99ef08200ca/Sources/CADTopology) | depends on | BRep volume and original topology | Original solid query owner | No complete solid first/second moments |
| [Tests](../../../Tests/SwiftMechanicsCADTests/DESIGN.md) | used by | Analytic and refusal oracles | Observable adapter guarantees | Tests use public products |

## Architecture
```text
bounded source/occurrence preflight -> builtin exact evaluation -> original BRep validation
 -> source ID + pin + revisions + fingerprint + units/tolerance -> sealed admission
query expected identity -> occurrence/body ownership -> original stable CAD query
 -> local SI witness + caller placement -> mechanics-frame witness
```

## Contracts and Invariants
CADGeometryAdmitting.admit receives the actual public CADDocument, explicit occurrence requests, source/query limits and exclusive work. Supported active independent feature nodes contain primitives or involute gears with no dependency/input edges; parameter expressions are visited under caller node/depth/metadata ceilings. Suppressed, selection-dimension and unsupported feature graphs fail explicitly instead of returning selected partial geometry. Record limits are checked before adapter traversal/allocation; evaluated topology is checked before retention. These limits bound adapter-owned records and visits only, not original CAD evaluation allocation or work.

Each admitted source identity contains the exact provider pin, document ID, design and parameter revisions, sourceFingerprint, units and modeling tolerance. Every query compares its expected identity before stable selection. The CAD source fingerprint does not include revision counters/document ID, and the original stable resolver accepts direct same-ID selections after shape edits; neither alone establishes mechanics freshness. No API consults a mutable external document or silently migrates a stale anchor.

Occurrence IDs, mechanics body IDs and mechanics frame IDs must each be unique and have the correct identifier kind. Each occurrence explicitly selects one source feature with exactly one actual body output. Repeated definitions may share that CAD body but receive distinct mechanics identities and placements. Explicit Material.validate and positive nonnil SI density are required. Existing CAD body material IDs, when present, must match the supplied selection. Missing, ambiguous or contradictory mappings fail as a whole.

Anchor enumeration returns original stable references tied to the admitted source and occurrence. Query admission checks occurrence/body/subshape membership and compares the original current geometry signature before invoking public CAD queries. Surface witnesses retain original local point/outward normal and transformed point/normal; edge witnesses retain original point/tangent and transformed values. CAD expression lengths already resolve to SI; display units are bound but never multiplied into the evaluated coordinates again. Volume is invariant under rigid occurrence placement and remains an original CAD measurement, not inertia evidence.

The callable exactMassProperties path has an INCOMPLETE_IMPLEMENTATION marker and always returns exactMomentsUnavailable after source/occurrence validation. Solid volume, face centroid, primitive parameters or a mesh are never substituted for CAD-owned complete solid geometric moments. Proxy/FEM creation, automatic shaft/phase/gear-law binding and Runtime migration are absent.

## Runtime Flows
Preflight and cancellation polling precede fingerprint/evaluation, then original evaluator and BRep checks complete before issuance. Queries poll before source association, during owned records and after original supplier calls; cancelled calls return no witness/admission. CAD's original operation is synchronous and retains its own cancellation/resource semantics. There is no hidden retry or fallback.

## State, Ownership, and Lifecycle
Snapshot and identity/occurrence arrays are immutable Sendable backing. Admission has no public raw initializer. Public request/value data cannot create a snapshot authority. Work counters, expression traversal stack and output arrays are exclusively local; checked overflow and caller caps precede owned growth. No shared mutable state or platform conditionals occur.

## Failure, Concurrency, and Constraints
CADAdapterError preserves nested CAD kernel/feature/topology/material/geometry/unit/schema errors and mechanics core errors. Adapter-owned failures distinguish invalid input, unsupported source, stale source, wrong occurrence/subshape, duplicate mapping, missing density, capacity, cancellation and missing exact moments. Unknown CAD failures are explicit providerFailure, never success. Work records positive owned visit/metadata prefixes on failure; it does not estimate opaque original CAD work.

## Verification and Change Impact
Tests admit real box/cylinder/gear sources; compare original volume, face/edge frames and two translated/rotated repeated occurrences; verify millimeter source quantities are not scaled twice; bind source pin/document/revisions/fingerprint/units/tolerance independently; demonstrate original same-ID resolver behavior then adapter refusal. Missing/deleted/cross-body anchors, duplicate identities, material errors, unsupported graph, record/work/depth limits, cancellation and exact-moment refusal return no successful admitted value. Fresh reevaluation reproduces identity and queries. Owner isolated whole-package Native proof precedes root external public verification; CAD and mechanics producers remain unchanged.

AF28 selected behavior is qualified by the [executed owner Native evidence](../../../Tests/SwiftMechanicsCADTests/DESIGN.md#executed-af28-native-evidence): 9 actual original-provider success/refusal tests. Production/test source is frozen after causal compiler and fixture repairs. The exact-moments gap remains explicit; future producer moments change this contract and require new physical oracles.
