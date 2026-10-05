# Accepted-Time Sensor Pipeline

## Purpose and Scope

Parent: [Observations](../DESIGN.md). Children: none. This component owns the selected SE-005..008 sensor processing, accepted-time scheduling, bounded headless buffers and their RT-003/006 continuation/lifecycle obligations. It consumes qualified625f759 compiled mechanics and immutable encoder, mounted motion, IMU and identified wrench observations. Contact/range/tactile adapters are not admitted until their separate raw owner qualifies its source contract.

This document fixes a synchronous pull domain. The initial source domain is built-in source-bound encoder and IMU scalar channels. Wrench/contact/range/trigger selectors explicitly refuse until their corresponding pipeline adapter is qualified. It does not qualify behavior, asynchronous streams, dense mechanical interpolation, arbitrary event decoding, action application, model migration or cross-build bitwise determinism. Root owns parent indexes, registration, integrated execution and commits. [Dedicated tests](../../../../../Tests/MechanicsSensorPipelineTests/DESIGN.md) own this component's behavioral evidence.

## Responsibilities and Boundaries

Own observation schema, scalar channel order/units, processing settings, sampling and delivery clocks, explicit interpolation/event treatment, seeded sensor random counters, bounded pending/ready records, replay and read-lease lifecycle. Raw measurement meaning, frame transformations and physical fidelity remain with the original observer. Integration and Runtime retain their original trial, admission, commit, cancellation and physical state authority. Control owns its controller clock, held command and control contributor; sensor state has no mutable overlap with it.

No externally supplied ObservationSource, RuntimeAcceptedState, ModelStamp or timestamp alone authorizes publication. The public owner constructs and privately retains a real final RuntimeSession, never exposing that underlying owner. The same compiled model, complete physical state and required sensor contributor must be associated before a reading can be released. A future generic raw provider must retain the complete prepared physical source and have a checked original-source contract; anonymous arrays or header-only matching are not an admitted provider port.

## Related Designs

| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Observations](../DESIGN.md) | parent | Immutable typed physical quantities | Scheduling does not upgrade raw fidelity |
| [ObservationRecords](../ObservationRecords/DESIGN.md) | depends on | Actual compiled source preparation and bounded metadata | Prepared source is not Runtime commit authority |
| [KinematicObservations](../KinematicObservations/DESIGN.md) | depends on | Encoder and mounted motion | Preserve distinct position/rate/velocity charts |
| [InertialObservations](../InertialObservations/DESIGN.md) | depends on | Original specific force and gyro | Acceleration authority remains explicit |
| [WrenchObservations](../WrenchObservations/DESIGN.md) | depends on | Identified force/impulse quantities | No inferred bearing decomposition or impulse duration |
| [Runtime Sessions](../../../Execution/Runtime/Sessions/DESIGN.md) | depends on | Real bound trial, commit, observe and shutdown | Callbacks and release remain outside locks |
| [Runtime Checkpoints](../../../Execution/Runtime/Checkpoints/DESIGN.md) | depends on | Complete required contributors, codec and restart | No filtered checkpoint or omitted sensor state |
| [Integration Stepping](../../../Execution/Integration/Stepping/DESIGN.md) | depends on | RuntimeSessionOperating.performTrial | No integrator or equation modification |
| [Tests](../../../../../Tests/MechanicsSensorPipelineTests/DESIGN.md) | used by | Original physical and lifecycle counterexamples | Root separately owns the three-profile composition |

## Architecture

```text
immutable definition + compiled model + original required handler
  -> sensor-aware full contributor registry/checkpoint handler
  -> private real RuntimeSession

original Integrator -> SensorPipelineSession.performTrial
  -> original operation on real bound RuntimeTrial/RuntimeStepControl
  -> reject: no sensor staging
  -> accept: raw endpoints -> clock/interpolation -> processing -> bounded queues
             -> replace declared sensor contributor in the same trial
  -> original Runtime admission/finish: publish all fields together or retain prefix

read request -> bounded pipeline lease -> real RuntimeSession.observe
  -> decode committed sensor queue and validate complete source/schema
  -> immutable bounded batch -> lease exit
```

### Public operation shapes

The required `SensorPipelineOperating` protocol extends RuntimeModelReplacing and adds a non-generic `readBatch(_:operation:)` requirement with a synchronous `@Sendable` callback and typed SensorPipelineFailure. RuntimeSessionOperating requirements, return values and typed RuntimeFailure remain unchanged. The inherited observe operation delegates directly, preserving the original accepted-prefix query during an already active trial; sensor readBatch has the separate checked lease/mutation exclusion contract. `SensorPipelineSession<BaseCheckpoints: RuntimeCheckpointHandling>` is the concrete owner. Its constructor consumes an immutable definition/admission owner and a full sensor-aware original handler, and constructs the private RuntimeSession itself. Rich construction, trial staging, checkpoint validation and batch decoding use separate noninline phases; no large aggregate configuration/result is added to the existing Runtime callback ABI.

The additive required operation has this exact shape; these are proposed new declarations, not existing source:

```swift
public protocol SensorPipelineOperating: RuntimeModelReplacing {
    func readBatch(
        _ request: SensorBatchReadRequest,
        operation: @Sendable (SensorBatchLease) throws(SensorPipelineFailure) -> Void
    ) throws(SensorPipelineFailure)
}
```

`SensorBatchReadRequest` specifies exact schema identity/version, world identity, model revision, the exclusive ready-sequence cursor and an explicit row/scalar bound. `SensorBatchLease` exposes an immutable batch only through a checked synchronous read operation. Its owner, epoch and active/closed state are issued internally. Callers cannot construct an accepted batch or a valid lease. The lease retains backing storage; scoped borrowed views cannot escape, while deliberately returned owned immutable records may outlive the session. No unsafe pointer port is required by this domain.

`SensorPipelineContributorHandler<Original: RuntimeContributorHandling>` declares the disjoint union of original schemas and the sensor schema and routes each complete record to its actual owner. `SensorPipelineCheckpointHandler<Base: RuntimeCheckpointHandling>` validates sensor/physical/sequence/configuration association and delegates the full checkpoint to the original handler. The original handler must already recognize the union registry; no sensor record is stripped to make admission succeed. Migration and replaceModel are explicitly refused with a typed unsupported-domain failure until the sensor mapping/schema and state migration have a separate contract; callable refusal branches carry the incomplete-implementation marker.

## Contracts and Invariants

### Source and publication authority

RuntimeAcceptedState can be produced by public checkpoint admission, so its sealed initializer does not prove that an arbitrary supplied value is this owner's committed state. Publication input comes only from the private real session's successful finish or observe callback. Snapshot remains an immutable consistent Runtime query, including during work and after closure; it is not an input-based sensor publication method.

The raw preparer uses the captured compiled model and the exact complete physical state, including ordered prescribed-anchor poses, velocities, accelerations and sample times. Model identity/revision, q/v/a, time, body/frame/layout and schema association are checked within admitted scalar/metadata bounds. Solved acceleration cannot silently replace an accepted prefix: this initial pipeline prepares raw observations with solved=nil and retains supplied-state acceleration authority. Interpolated records retain their actual raw endpoints and cannot masquerade as an original raw header at another time.

The wrapper invokes the original trial operation once. On reject it neither stages sensor state nor exposes candidate raw data. On accept it obtains the original accepted prefix from its privately held actual session, checks the sensor history against that complete prefix and stages the candidate endpoint, sensor counters and queues through RuntimeTrial.replaceContributor. Failure, cancellation, shutdown or final admission rejection leaves physical state, sensor contributor and all RNG state at the original accepted prefix. No outside queue/history mutation occurs after a callback merely returns accept.

### Schema and units

An immutable versioned schema fixes world/stream identity, ordered distinct sensor and component IDs, body/joint/frame association, physical dimensions, velocity convention, temporal meaning, source fidelity, interpolation rule, processing order and settings. All metadata, components and value slots have caller bounds. Values remain SI quantities; bias/noise half-width/quantization origin and step/saturation bounds use that component's dimension. The schema's canonical settings are serialized or compared in full, not represented by a hash-only admission shortcut. Unsupported versions or changed units/order/settings/model revision fail explicitly.

Headless batches carry schema/version, model/world identity, sequence range, sampling/source/delivery metadata, raw provenance, processing flags and an explicit sample/dropout status. Missing samples are never valid zero measurements. A dense export, if provided, requires a validity mask alongside its declared fill representation. An action-schema compatibility request compares the explicit schema identity/version/ordered dimensions; this component neither applies actions nor interprets controller state.

### Processing and seeded randomness

The first admitted statistical model is bounded symmetric uniform additive noise with finite nonnegative per-component half-width and a finite constant per-component bias. No Gaussian or drifting-bias claim is made. Processing order is raw value, constant bias, additive noise, optional quantization, then optional saturation. Every intermediate must be finite. Quantization requires a finite positive step and finite origin, uses nearest-even ties and refuses an overflowing normalized bin/product. Saturation uses finite inclusive lower/upper bounds and reports which values clipped. Disabled operations are explicit schema settings.

Each sensor has a caller-specified distinct UInt64 stream key. Its seed is derived from the explicit root/world seed and stream key with the existing public RuntimeRandomState.worldSeed operation. The same operation indexed by a checked sensor draw counter supplies the existing SplitMix64 sequence without new private RNG internals or replaying all preceding draws. Counters, keys and derived seeds live only in the required observation contributor. Runtime's physical RNG remains unchanged by these separately identified sensor streams. Counter overflow or a caller draw bound is a typed failure before reuse.

The uniform conversion uses the upper 24 bits and midpoint mapping (bits + 0.5)/2^24. Its symmetric-noise discrete mean is zero and variance is halfWidth^2*(1-2^-48)/3. The distribution's discrete mean and variance, draw ordering and algorithm version are part of the schema. Each scheduled sensor frame reserves one dropout draw and one noise draw per numeric component, including disabled/zero-width noise and dropped frames. Thus a dropout does not change subsequent draw association. A finite probability in [0,1] selects a seeded Bernoulli dropout; the frame retains tick/sequence/status and no valid numerical payload. Every channel and tick has one stable processing order.

### Accepted-time schedule and interpolation

The fixed clock is origin + tick*period, with finite origin, strictly positive finite period, checked integer tick bounds, finite products and strictly increasing representable times. Repeated addition, wall-clock time and rejected trial endpoints do not define the clock. Initial origin cannot require reconstructing an unobserved past. Initial-tick emission is an explicit setting and, when enabled, is constructed for the initial physical state but becomes readable only after real Runtime construction/admission succeeds.

An accepted continuous interval processes precisely the not-yet-issued ticks in (previousAcceptedTime,currentAcceptedTime]. Same-time continuous transactions emit no duplicate periodic tick. The candidate interval admits its complete tick count and scalar/work/byte bounds before raw evaluation, random draws and allocation. Tick count beyond the caller maximum fails the whole transaction rather than looping without a bound.

Three explicit sampling modes are admitted: endpointOnly requires every due tick to equal the actual accepted endpoint; previousAcceptedHold reports the true retained raw source time separately from the scheduled tick; linearObservationComponents interpolates numeric observer components between actual accepted raw endpoints, retains both bracket identities/times and reports approximate interpolation fidelity. The last mode is not a dense ODE solution, quaternion/chart interpolation or reconstructed intermediate physical acceleration. Unsupported quantity/chart/temporal combinations fail. Discrete states and instantaneous impulses cannot use linear interpolation.

Event treatment is explicit, with no inference from a discontinuous-looking value. Continuous interpolation requires a declared event-free interval and refuses registered event histories without an admitted boundary adapter. Endpoint event sampling uses an explicit pre/post side and retains an event identity/accepted sequence; equal-time event and periodic records have separate keys. A smallest sensor-owned trial adapter may accept an original producer's typed boundary record and validate it against actual contributor/pre/post physical state; it cannot treat arbitrary timestamp metadata as event authority. Unknown event codecs and unlocated event crossings fail, never silently interpolate. The original Integrator exposes no generic dense-output or event-history callback; this domain does not invent one.

### Delay, queues and overflow

Delay is an explicit finite nonnegative number of seconds bounded by the caller. A frame retains scheduled sampling time, actual raw source time or bracket, nominal release deadline (sample time + delay), and actual accepted delivery time. It becomes ready at the first accepted boundary whose time reaches the deadline. Runtime/wall-clock execution duration is not sensor delay. Deadline overflow fails explicitly.

The pending queue has caller row/scalar/byte bounds and orders by deadline, sampling time, sensor key and tick/event key. Its overflow always rejects the whole candidate transaction. Matured frames move to a bounded ready queue in deterministic order and receive a checked monotonically increasing ready sequence. The ready policy is explicitly either refuseOverflow or retainLatestWithReportedOverrun. Retain-latest evicts the oldest complete records, persists the retained sequence floor/eviction count, and makes a request behind that floor fail with overrun evidence. It never silently claims a contiguous batch. Queue contents and floors are persisted contributor state; consumer speed does not change the deterministic retention algorithm or noise draws.

Reads are non-destructive. The caller owns its consumption cursor, so the pipeline needs no artificial sensor-only Runtime transactions, uncheckpointed acknowledgement mirror or guessed integrator sequence updates. A controller that uses a cursor in future computation must persist that cursor in its own declared contributor. Cold restart restores the exact retained queue/sequence/floor; redelivery from a caller's earlier cursor is explicit and deduplicated by the stable sequence, rather than an exactly-once external side-effect claim.

## Runtime Flows

Initialization validates definition/schema/seed/domain/capacity, prepares actual initial raw data in a separate phase, creates the initial sensor contributor, and admits the complete original checkpoint through the real session. Failure releases resources once and publishes no batch.

Trial wrapper phases are original operation, source/clock preflight, raw endpoint preparation, bounded schedule/processing, serialization/replaceContributor and original Runtime finish. Every rich phase owns immutable backing or exclusive local work. External raw provider calls, Runtime callbacks and codec operations run outside pipeline locks. Safe-point work blocks use the actual RuntimeStepControl and preserve known supplier consumption/failure information.

Restart delegates to the original codec and full sensor-aware checkpoint handler. Exact schema/settings/source/seed/counters/queue bounds are validated before the original session publishes. A successful restart advances the pipeline lifecycle epoch before new leases are admitted; failure retains the epoch and complete accepted prefix. Existing active read leases make restart/mutation busy, not invalid memory. No queue is reconstructed from a new seed or a different raw model after restart.

## State, Ownership, and Lifecycle

| State | Native / WASM / Embedded storage | Entry points | Persistence/release |
|---|---|---|---|
| Physical accepted prefix and original Runtime RNG | Existing private RuntimeSession Mutex storage | Original Runtime requirements | Original full checkpoint and release semantics |
| Sensor settings, clock/counters, endpoint evidence, delay/ready queues | Immutable definition plus contributor bytes; exclusive trial-local staging | Wrapper performTrial and full checkpoint admission | Original atomic checkpoint/restart |
| Pipeline operation/read lease count, epoch, closing/release flags | One common Synchronization.Mutex<Metadata> | Checked checkout/read/restart/shutdown | Ephemeral lifecycle only; retired storage/callbacks outside lock |
| Read batch backing | Immutable retained owner, bounded logical slots | Checked lease read | Exactly-once lease close/deinit |

No target-conditioned state owner, lock removal, Sendable weakening, unsafe pointer or hidden mutable cache is admitted. Pipeline metadata never mirrors sensor history or queue contents as a second authority. Locks protect only short metadata operations; calls into Runtime, raw observers and user callbacks occur after unlock. Two-phase checkout prevents lock nesting and reentrant deadlock. Mutation/restart is exclusive and read leases are bounded. Shutdown rejects new work/leases, requests original Runtime shutdown, drains active operations/leases, and releases each owned resource once. Retained owned immutable records remain safe; closed or wrong-epoch lease operations fail. The synchronous pull domain declares no AsyncStream; a stream port would need its own finishing/cancellation contract before source.

## Failure, Concurrency, and Constraints

Typed failures distinguish invalid schema/statistics/time domain, unsupported interpolation/event/model migration, stale complete source, nonfinite processing, contributor/codec corruption, queue overrun/capacity, invalid lease, busy/closed and cancellation, Read and construction failures retain original observer/Runtime payloads and known work. The inherited performTrial ABI has only RuntimeFailure; staging errors explicitly map to its stable code, sensor contributor, message and failedSupplierWorkUnavailable fields, and Runtime retains the accepted prefix. An original ObservationError payload cannot survive that fixed ABI and no external error mirror is introduced. Rich underlying failure data uses immutable reference-owned or indirect payloads so wrapping it does not add the AF30 large direct error-frame pattern. Existing RuntimeFailure ABI remains unchanged.

Caller limits cover sensors/components/metadata, tick horizon/ticks per accepted interval, rows/scalars/bytes in each queue and batch, draw count, leases/retained backing, raw numerical/supplier work, contributor encode/validation scratch and checkpoint envelope. Checked sums/products and shape/domain checks precede allocation/traversal. Runtime contributor bytes/schema/validation capacity must admit the complete sensor payload alongside all original contributors. The required contributor validator reserves twice its complete decode/raw-validation work for its own pass plus the full checkpoint association pass. Each pass admits at most half the remaining validation work. Decoding preflights a conservative eight-times-payload scratch bound plus original numerical peak storage before accepting the validation budget; these are accounted bounds, not allocation measurements. Owned batch exports have caller-owned retention after lease close; the pipeline bounds its own active leases/backing and per-export shape, not arbitrary caller copies. No guessed cap, unbounded retry or relaxed physical tolerance substitutes for these bounds.

Exact Swift6.4.0 with matching Native/WASM/Embedded SDKs and the original131072-byte WASI stack remain the qualification envelope. Source uses one common implementation/isolation. Noninline owner phases and compact failure paths must be demonstrated by actual composition, not inferred from this document or compilation alone.

## Verification and Change Impact

Dedicated tests own seeded replay/statistics, transform order/flags, invalid processing domains, adaptive rejected-step fixed clock, declared interpolation/event refusal, full physical source counterfeit refusal, delay timing, explicit slow-consumer overflow, contributor/RNG rollback, exact checkpoint/cold restart, schema/batch compatibility and read/restart/shutdown/resource lifetime behavior. Root qualifies original profiles with real Runtime and raw observers. No source or build is authorized by this design handoff alone; root first indexes and freezes the contract.

Changes to raw source semantics, Runtime publication/contributor/codec authority, integration endpoint treatment, schema/settings or lifecycle require rechecking the corresponding child and this composed path. Control remains a separate consumer of immutable identified readings; raw ContactRangeObservations is a later qualified adapter, not an unfinished build dependency.
