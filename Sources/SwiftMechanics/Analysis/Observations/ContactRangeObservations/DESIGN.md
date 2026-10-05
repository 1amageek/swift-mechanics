# ContactRangeObservations

## Purpose and Scope

Parent: [Observations](../DESIGN.md). No children. Own the selected SE-004 raw contact, tactile and range boundary on qualified625f759 suppliers. The owner implementation and independent Native proof are complete for the selected raw domain. Root owns canonical/public/profile composition; Native evidence is not generalized to those profiles.

The complete selected domain is rigid body-fixed collider recipes, analytic spheres, sharp zero-margin boxes and half-spaces, original supported witness pairs, sampled trigger overlap, bounded rays, and instantaneous current compliant contact laws. Range may retain declared approximation provenance: an analytic query of a supplied proxy does not certify its source CAD shape. Unsupported shape/query pairs, rounded-box range, nodal contact, continuous trigger crossing, pressure/contact area and impact sensing remain explicit failures or separate prerequisites. A scene is a caller-declared catalog; completeness of the physical world is not inferred.

## Responsibilities and Boundaries

Own source-bound scene issuance, actual collider placement and mounted rays, original hit/witness association, material-basis construction, actual rigid point rates, current tactile force/couple observation, geometry fidelity, units, frame, reference point and exact timestamp. Do not integrate dynamics, issue/advance contact history, decode history, manufacture query records, infer pressure/bearing allocation or publish Runtime acceptance. SensorPipeline owns accepted-prefix association, schedules, noise, buffering and schemas.

An issued ContactHistory is a constitutive producer record. Its designation as accepted and its bristle/material-layout association are an explicit caller declaration. This child proves the current source geometry and rates, exact identity/pair/time association and original current law acceptance; it does not certify that the history was committed by Runtime or evolved by a particular mass/load model. Original history and law are retained unchanged.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Observations](../DESIGN.md) | parent | Raw mechanical observation ownership | Root owns indexing and composition | No pipeline authority here |
| [ObservationRecords](../ObservationRecords/DESIGN.md) | depends on | Required original source preparation and policy | Actual compiled model/state evaluation | Use solved:nil; no internal source constructor |
| [KinematicObservations](../KinematicObservations/DESIGN.md) | depends on | Required mounted motion operation | Actual mount pose and full derivatives | Injected success requires original evidence |
| [Compiler records](../../../Modeling/Compiler/CompilationRecords/DESIGN.md) | depends on | Sealed model and state owners | Complete source admission | IDs/revisions do not replace owner authority |
| [Collision geometry](../../../Physics/Collision/Geometry/DESIGN.md) | depends on | Required witness/ray operations | Original analytic geometry and residuals | True miss is distinct from unsupported |
| [Collision discovery](../../../Physics/Collision/Discovery/DESIGN.md) | depends on | Required sorted rayHits | Bounded scene query | Caller selects targets; lower rayHits checks enabled only |
| [Collision persistence](../../../Physics/Collision/Persistence/DESIGN.md) | depends on | Required triggers/manifold operations | Original sampled overlap and contact IDs | No continuous-crossing claim |
| [Current contact sampling](../../../Physics/ContactLaws/Sampling/DESIGN.md) | depends on | Required sample with original history | Instantaneous force/couple and power checks | No dt or return-map substitution |
| [Material tooth contacts](../../../Physics/Transmissions/ToothContacts/DESIGN.md) | coordinates with | Documented common midpoint/material-axis convention | Existing physical convention reused | No dependency on its internal helpers |
| [Runtime sessions](../../../Execution/Runtime/Sessions/DESIGN.md) | used by | Immutable accepted state supplied to pipeline | Accepted observation lease | Raw records do not imply acceptance |
| [Tests](../../../../../Tests/MechanicsContactRangeObservationTests/DESIGN.md) | used by | Independent physical and refusal proofs | Dedicated owner | Execution evidence is recorded after actual runs |

## Architecture

```text
sealed compiled model/state + bounded declared collider recipes
  -> ORIGINAL source preparer (solved:nil)
  -> actual body poses + body-fixed placements
  -> producer-file opaque admission -> immutable ContactRangeScene

scene + mount + ray / trigger prefix / identified tactile binding
  -> original mounted motion + actual geometry/point rates
  -> original ray/witness/trigger/current services + evidence verification
  -> producer-file opaque result admission -> immutable raw observation

raw observation + original RuntimeAcceptedState -> SensorPipeline-owned publication
```

## Contracts and Invariants

### Fixed public port

Each primary type occupies its own Swift file. These signatures are the design handoff, not existing implementation evidence.

```swift
public protocol ContactRangeScenePreparing: Sendable {
    func prepare(model: CompiledMechanicalModel, state: CompiledKinematicState,
                 colliders: [ObservationColliderBinding], revision: UInt64,
                 policy: ContactRangeObservationPolicy, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> ContactRangeScene
}

public protocol ContactRangeObserving: Sendable {
    func range(scene: ContactRangeScene, mount: ObservationMount,
               ray: CollisionRay, targets: [EntityID],
               policy: ContactRangeObservationPolicy,
               collisionWork: inout CollisionWork, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> RangeObservation
    func triggers(scene: ContactRangeScene, mount: ObservationMount,
                  filters: CollisionFilterPolicy, previous: TriggerObservation?,
                  sampleIndex: UInt64, policy: ContactRangeObservationPolicy,
                  collisionWork: inout CollisionWork, work: inout NumericalWork)
        throws(ContactRangeObservationError) -> TriggerObservation
    func tactile(scene: ContactRangeScene, mount: ObservationMount,
                 contact: TactileContactBinding, policy: ContactRangeObservationPolicy,
                 collisionWork: inout CollisionWork, contactWork: inout ContactWork,
                 work: inout NumericalWork)
        throws(ContactRangeObservationError) -> TactileObservation
}
```

Implementations are ReferenceContactRangeScenePreparer() and ReferenceContactRangeObserver(geometry: any CollisionGeometryQuerying = AnalyticCollisionQueries(), discovery: any CollisionDiscovering = ExhaustiveCollisionDiscovery(), persistence: any CollisionPersisting = ValueCollisionPersistence(), current: any ContactCurrentEvaluating = CompliantContactCurrentEvaluator(), kinematics: any KinematicObserving = ReferenceKinematicObserver()). All calls through existentials are actual non-generic protocol requirements.

ObservationColliderBinding is an immutable caller-declared recipe with colliderID, body, geometryRevision, shape, margin, representations, expectedSourceRevision, resolution, colliderToBody and filter. It carries no world pose. Source world frame and revision are derived by the issuer. Actual model collision representation/provenance is associated explicitly; declared proxy shape/fidelity is retained rather than claimed to be independently reconstructed CAD geometry. Duplicate colliders, unknown bodies and unsupported representations fail before publication.

ContactRangeScene is an immutable final Sendable owner retaining source:ObservationSource, colliders:[ObservationColliderBinding], collision:CollisionSnapshot and revision:UInt64. Preparation calls the original required ObservationSourcePreparing operation with the exact sealed model/state and solved:nil. Collider poses come from that issued source's actual body motion and declared fixed placements. No public/internal raw-field scene constructor exists: construction consumes an opaque admission whose initializer is fileprivate to the scene issuer file. The token is not exposed from any result. Other same-module components cannot mint authority from copied fields.

ContactRangeObservationPolicy retains original observation:ObservationPolicy, query:CollisionQueryPolicy and contact:ContactAcceptancePolicy, with explicit nonnegative maximumColliders, maximumHits, maximumTactileBindings, maximumTriggerRecords and maximumMetadataBytes. Existing numerical/contact/collision tolerances remain the original supplied policies. ObservationPolicy's cancellation closure is also checked at new phase/loop/publication boundaries; lower CollisionWork/ContactWork retain their original Task cancellation semantics.

TactileContactBinding retains firstCollider, secondCollider, pair:ContactLawPair, accepted:ContactHistory, tangentLayoutRevision and firstMaterialTangentInCollider:Vector3. Both collider IDs must be distinct, rigid, eligible, nontrigger, and belong to distinct bodies. The mount body must be one of these bodies; output sign is force/couple on that identified mounted body. Full body/frame/geometry/tangent-layout identity, pair and exact time must match the original issued source and history. Material-site histories fail unsupportedRepresentation.

Every raw result retains scene, mount, original mounted motion, exact model/state/time, and explicit expressedFrame. Result constructors consume observer-file opaque admissions; no public/internal raw-field result construction port exists. Source identity includes complete physical state, scene recipes and collision revisions, not IDs or time alone. A raw record does not contain an accepted Runtime claim.

RangeObservation retains the actual world ray, selected target IDs and ordered hits:[CollisionRayHit]. CollisionRay supplied to range is explicitly in sensor-local axes, including its origin offset and bounded SI maximumDistance. Original mounted pose transforms it to world. Hits retain original world point/outwardNormal/feature/geometry identity, distance in meters, declared resolution/representation quality and approximation deviation. Empty hits is a successful miss only after every selected eligible target query succeeds. Disabled targets are omitted under an explicit enabled-only range rule; same-body targets are allowed if explicitly selected. Layer/mask/trigger filters are not silently imported from contact discovery. Duplicate/unknown targets fail. Unsupported queries anywhere in the selected catalog fail rather than produce a partial miss.

TriggerObservation retains original CollisionTriggerUpdate, sampleIndex, actual current overlap witnesses and source-bound collision catalog. The selected deterministic filter domain uses declared joint exclusions/allowSameBody and collider enable/layer/mask/trigger flags; filters.user must be nil. Stateful external user-filter semantics are an unsupportedSensorModel prerequisite, not silently ignored. Previous state must be a genuine sealed TriggerObservation with the same full original compiled descriptor/stamp/tree/layout and full sensor mounting, identical geometry/filter/recipe identity, and a strictly earlier source time; original provider enforces sampleIndex+1. CompiledMechanicalModel is an immutable value, so no invented reference-owner identity is used. Separately compiled genuinely equivalent models may associate after bounded full equality; a changed descriptor with a copied stamp fails. World poses may evolve through genuine new sources. Filter changes/catalog replacement need a fresh prefix at index0; this raw child does not decode trigger continuation. Original trigger events retain sampled enter/exit semantics; current witness geometry is recorded for active intersections, while exit association retains previous issued witnesses without recursively retaining the entire prior observation chain. No force is inferred from overlap or an entered event.

TactileObservation retains original witness, common world applicationPoint, actual world material basis, relativeVelocity, relativeAngularVelocity, response:ContactCurrentResponse, unchanged accepted history and side. Force/couple about the mounted sensor origin are expressed in sensor axes, with explicit sensor frame and SI units N/N m. Original witness pointA/pointB remain separate geometry diagnostics. Application point is (pointA+pointB)/2 for both bodies. Actual v(p)=body.linear+body.angular cross (p-bodyOrigin), relative v=vB-vA and relative omega=omegaB-omegaA are recomputed from the original source. Project the declared first collider material direction onto the current tangent plane, normalize it, then construct the second tangent by n cross first. A parallel/degenerate projection is typed unsupportedChart; no arbitrary fallback axis. Original bristles are interpreted in that explicit advected material layout, without transport inference.

Call original ContactCurrentEvaluating.sample at the exact source time, without dt or history advancement. Force/couple on A are negatives of B at the common application point. Shifting to the sensor origin uses moment+offset cross force before rotating to sensor axes. Check original response/history association and both original power residuals. This certifies constitutive force observation under the declared geometry/axis/history assumptions, not acceleration or mass/load solution. Contact force is never inferred from a trigger and no impulse is divided by an invented interval. An impulse/finite-interval contact record is not accepted by this port.

### Supplier evidence and source acceptance

Injected successes are admitted only in the exact original reference-equivalent domain, explicitly documented on operations. Recompute original mounted motion, geometry/query results and current response using unchanged caller policies and budgets. Verify full original source, poses, rates, geometry, features, fidelity, law/history and outputs before issuance. Equivalent quaternion signs compare through original rotation matrices. A real supplier result from another source, a changed mounting, a moved proxy or changed current separation/velocity must fail even if IDs, revisions and time match. A caller cannot supply precomputed ray/witness/current output to bypass this verification. Canonical recomputation is additional accounted work, not an uncharged trusted bypass.

## Runtime Flows

Preparation: bounds/metadata -> original compiled source evaluation -> placements -> scene consistency -> cancellation -> opaque issuance.

Observation: bounds/source/mount admission -> original mounted pose/rates -> operation-specific query/point rates -> seeded supplier invocation -> original verification -> shift/rotation and metadata -> cancellation -> opaque issuance. No retry or fallback follows failure. Trigger prior state remains unchanged on rejection. Tactile never changes accepted history.

SensorPipeline constructs this scene from its same compiled model and RuntimeAcceptedState.physical. It compares complete stamp and physical q/v/acceleration/prescribed-anchor pose/v/a/time to the checkpoint, not only headers. Since scene preparation uses solved:nil, it preserves the exact supplied accepted acceleration. Pipeline owns acceptedSteps/ordering/rejected-trial suppression; this child has no Runtime session state, scheduler, noise/RNG or contributor codec.

## State, Ownership, and Lifecycle

All recipes/scenes/results/services/policies/errors are immutable Sendable on Native, ordinary WASM and Embedded. Scene/result backing retains original immutable owners; arrays use owned COW backing rather than borrowed escaping views. Work is exclusive operation-local inout. No mutable cache, asynchronous callback, shared sensor history or target-conditioned isolation exists. Trigger evolution is value-in/value-out; pipeline owns publication. Noninline source, geometry invocation, supplier acceptance, point-rate/current sampling and final publication phases keep rich temporary lifetimes separate under the original131072-byte stack reservation. Stack reduction is not claimed without emitted/runtime qualification.

## Failure, Concurrency, and Constraints

ContactRangeObservationError owns typed invalidInput, unsupportedSensorModel, unsupportedRepresentation, unsupportedChart, staleSource, invalidSupplierEvidence, supplierLedgerReplaced, temporalMismatch, capacityExceeded, cancelled and wrappers for original ObservationError, CollisionError, ContactCurrentError, CoreError and NumericalError. Opaque invocation failures use separate observationSupplier/collisionSupplier/currentSupplier wrappers and report failedSupplierWorkUnavailable; replaced ledgers also mark unknown work. Known pre-admission validation/arithmetic/budget failures do not invent unavailable supplier work. Original law/query rejection remains visible; unsupported must not turn into empty hits or zero force. Callable incomplete branches require the original English marker before dispatch.

Bounds precede allocation, equality and supplier calls: collider/target/history/trigger records, per-record UTF8 metadata and aggregate NumericalWork, checked scalar-slot products and collision/contact result capacity. Policy must admit exact output counts; never truncate results. Scene storage and per-result envelopes are explicit conservative logical accounting units, not allocator bytes. Finite pure Core arithmetic is charged under NumericalWork. Original source/frame service calls use declared opaque call quanta, not invented instruction counts.

Before each injected callback irreversibly charge at least one unit into its original caller ledger, then retain the known admitted prefix. On success and failure verify identical budget fields and nondecreasing operations/iterations/peak storage; restore known prefix and fail on replacement. NumericalWork additionally retains its original budget; collision/contact budgets retain their original records/storage/operation limits. Canonical recomputation uses the same ledger. Cancellation checks preserve known work; unknown failed opaque work is explicitly unavailable. No output is issued on callback failure, reset, cancellation, budget exhaustion or failed source/original evidence acceptance.

## Verification and Change Impact

The [dedicated test contract](../../../../../Tests/MechanicsContactRangeObservationTests/DESIGN.md) fixes independent analytic range/trigger/tactile, source-swap and ledger refusal proofs. Qualified old observations/collision/current-contact suppliers remain frozen. Root registers the child DESIGN exclusion and dedicated test target, then integrates the exact frozen source with independent public assertions on original Native/ordinary/Embedded profiles and131072-byte guards. The owner proof below verifies actual selected Native behavior; public/profile success requires root execution. Changed source authority, material-axis/application-point convention or temporal meaning requires affected pipeline and raw tests; scheduler/noise ownership remains outside this child.

### Owner execution evidence (AF31.1)

One comprehensive scoped source/test review preceded the immutable production freeze. Native used committed625f759 plus only this child and its dedicated test overlay, with the root-prepared private manifest registering only MechanicsContactRangeObservationTests. No supplier, compiler flag, tolerance, stack reservation or shared manifest changed.

| Proof | Actual result |
|---|---|
| Exact toolchain | swift-6.4.0-RELEASE; arm64e Native, macOS14 target |
| Initial setup | Watchdog1200s, four jobs; exit0,111.79s |
| Initial behavior | Watchdog240s;15 declarations/4 suites executed;14 passed, one test oracle targeted a sphere behind its sensor |
| Finding-only repair | Only the zero-hit-capacity test selected the actual forward/inside sphere; production Swift remained unchanged |
| Recheck setup/behavior | Exit0,4.15s setup;15 declarations/4 suites passed in.012s |
| Profile boundary | Root owns unchanged original Native/ordinary/Embedded public composition and original131072-byte guards |

Exact commands, logs, freeze inventory and test ownership are recorded in the linked dedicated test DESIGN. All owner processes stopped after recheck; the exclusive Native cache was handed back to root. This evidence does not certify every unsupported SE-004 domain or complete the full210 requirements.
