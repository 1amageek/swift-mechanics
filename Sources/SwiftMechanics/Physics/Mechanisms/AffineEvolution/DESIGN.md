# AffineEvolution

## Purpose and Scope
Actual compiled scalar-tree affine invariant DAE evolution. Parent: [MechanicsMechanisms](../DESIGN.md). No children. Full IM16 requirements remain owned beyond this initial admitted subset.

## Responsibilities and Boundaries
Explicit index-reduced affine holonomic constraints over dynamic scalar revolute/prismatic coordinates on a fixed root. Real mass is assembled at every derivative. Stages and endpoints must satisfy original position and velocity rows; no projection or modification of Integrator endpoint. Nonlinear geometric loops and floating quaternion charts remain unqualified.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM16 ownership | Module composition | Root registers and qualifies actual paths |
| [Compiler](../../../Modeling/Compiler/DESIGN.md) | depends on | Compiled model state/evaluation | Actual tree and revision | No private reconstruction |
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | Scalar manifold/layout/state | Explicit qdot chart authority | No inferred q/v meaning |
| [Loads](../../Loads/DESIGN.md) | depends on | Zero external-load ledger | Existing facade uses no mapped external loads | Actual drive is passed separately |
| [StationaryLoads](../StationaryLoads/DESIGN.md) | planned dependency | Catalog, selection, explicit LoadWork execution | AF23 opt-in loaded motion | Design-only until lower Runtime proof |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | Caller work/capacity ledger | Separate supplier accounting | No unknown retry |
| [Dynamics](../../Dynamics/DESIGN.md) | depends on | Rigid equations and solve | Real compiled physical mass | No diagonal proxy |
| [Constraints](../../Constraints/DESIGN.md) | depends on | Required rank and evaluation | Original identified rows | Rank does not imply force or feasibility |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | coordinates with | Accepted physical transactions | Immutable accepted prefix | Model replacement has separate admission authority |
| [Integration](../../../Execution/Integration/DESIGN.md) | coordinates with | Equation and continuation witnesses | Actual stage/time acceptance | Exact chart readback |

## Architecture
```text
real q/v chart -> noninline rows/source admission -> immutable input owner
    -> noninline rigid assembly -> immutable system owner
    -> noninline constrained supplier invocation -> source/output association
    -> derivative -> exact endpoint publication
```
Actual dependencies used: CompiledMechanicalModel.evaluate; SmoothODEEquations required witnesses; IntegrationContinuationProvider and RuntimeSessionOperating trials; dynamics and constrained solver public contracts.

## Contracts and Invariants
Admission proves qdot=v by scalar manifold and explicit layout/authority validation, never by array length. Immutable equation binds model stamp/layout, all retained row IDs/scales and constant physical drive. Each derivative reserves/charges bounded operation-local buffers. Its orchestration admission envelope is checked `128*B + 4*n*n + 16*n + 4*n*m` scalar slots; this is a conservative structural reservation, not measured allocation, stack or copy usage. It covers owned q/v/zero-acceleration/chart arrays and retained sampled rows/system results. Public tree capacity bounds the immutable snapshot backing. Assembly, row evaluation and each constrained supplier have separate remaining ledgers whose evidence is absorbed with that envelope; retained immutable input backing is borrowed, not re-materialized. Integration owns accepted/rejected history; equation has no hidden cache.
All values and public witnesses are Sendable on every target. Frames, model/layout revision, temporal force versus impulse interpretation and physical units stay explicit. Output is published only after original physical acceptance.

## State, Ownership, and Lifecycle
Source records are immutable; workspace and authoritative NumericalWork are caller-exclusive values. Required suppliers execute outside locks. No global cache or mutable shared producer state is introduced. Bounded operation-local physical/snapshot/input/system/row contexts are immutable final Sendable owners. Their lifetime spans only one derivative call; phase callbacks consume public values and never mutate those owners. Rows/source setup finishes before assembly; assembly locals finish before constrained solve; solve ledgers/result handling finish before output association. Each phase is noninline to prevent rich past/future temporaries from overlapping lower callback frames. This adds no cache or shared mutable state. Structural scalar-slot budgets do not claim allocator or physical-copy measurements.

## Failure, Concurrency, and Constraints
The original public debug WASM stack is 128 KiB. Root measured an ordinary-WASM motion frame of 19,776 bytes retained over the frozen constrained solver (12,736 bytes), its accept phase (12,304 bytes), and WorldRigidBody.evaluate; cumulative Runtime/Integrator/public composition exceeded that original boundary. Motion now passes immutable reference contexts between noninline input setup, assembly, solver invocation and source/output association phases. The original callback ledger seeds, remaining budgets, success/failure absorption and unknown-work evidence are preserved. Structural reservation is retained; root owns exact frame diagnostics and target runtime qualification. Stack enlargement, backend fallback or edits to lower frozen producers cannot establish this owner's completion.

Typed failures distinguish stale binding, shape/domain/physical residual, cancellation, overflow, capacity and supplier error. Caller maxima are checked before allocation; checked integer products bound workspaces. Supplier work is separate from orchestration work; unknown partial supplier failure stops without retry. Ledger replacement/reset is rejected. Unavailable callable paths carry FIXME(INCOMPLETE_IMPLEMENTATION) and typed failure.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsMechanismsTests/DESIGN.md). Planned actual evidence: Torque-driven real compiled gear analytic q/v/reactions, RK4 and adaptive history/replay, invalid initial row/chart, supplier failure prefix, no projection. Root owns Native and exact original WASM/Embedded qualification after source freeze; declarations alone grant no qualification. Changed mass/row/scaling/chart or lifecycle supplier contracts require affected composition requalification.

The equation descriptor chart contains an exact bounded ASCII encoding of original affine rows, coordinate IDs/scales/time scale, physical drive and position/time domain, plus original acceptance tolerance. The Integration signature therefore rejects a physically different equation/catalog even when callers reuse the human identity. Hexadecimal UInt64 and Double bit patterns have at most 16 ASCII digits plus one delimiter; the complete maximum byte count is checked before materialization. Supplier failures stop; nested unavailable-work status is carried by the actual RuntimeFailure.failedSupplierWorkUnavailable bridge, while known ledger charges remain separate from unavailable partial work. Integration consumes that public evidence; qualification is pending root execution.

### Selected AF17 execution evidence

Native fixed/adaptive gear replay and inconsistent-initial-state tests passed. Original Native/WASM/Embedded public RK4 gear evolution and actual checkpoint replay execute with the same affine chart/physics. Exact profile identity and root logs are indexed by the [parent design](../DESIGN.md); the corresponding test owner retains the independent physical oracles. Private stack diagnostics are not qualification.

### AF20 selected public profile evidence
Root executed the final unmodified Native, ordinary-WASM and Embedded-WASM compositions with all path completion witnesses and exit zero. [Exact profile evidence](../../../../../Verification/FoundationVerification/DESIGN.md#af20-selected-original-profile-qualification) owns toolchain, stack, runtime and test-snapshot qualification. This extends only the selected public paths documented there; the remaining domain and concurrency limitations above persist.

### AF23 shared loaded path
The additive implementation is present; behavioral qualification remains root-owned. Existing constructor/zero-load facade, chart bytes and operation behavior remain compatible. A new opt-in constructor captures immutable catalog/selection and an operation-local StationaryLoadExecuting port. Its chart binds the complete canonical catalog signature; selected version/generation is the accepted continuation owner's dynamic authority. It implements the same SmoothODE witnesses and a required public loaded-motion operation:

```swift
public protocol StationaryAffineMotionComputing: Sendable {
    func loadedMotion(physical: KinematicState, selection: StationaryLoadSelection,
                      execution: any StationaryLoadExecuting, work: inout NumericalWork)
        throws(RuntimeFailure) -> StationaryAffineMotion
}
```
StationaryAffineMotion is an immutable bounded reference output holding actual RigidDynamicsSystem, original VelocityConstraintSample and accepted ConstrainedMotion. It exposes the source-bound system/rows required for sleep SPD/connectivity; no other owner reconstructs private dynamics. The equation's captured model/constraints/drive/catalog are validated against physical/selection. The non-Runtime operation works for full-checkpoint proof as well as stage/wake calls; it uses its supplied cancellation/admission/ledgers, not a fabricated RuntimeStepControl. Stage witnesses still admit actual Runtime control blocks before entering it.

One phased implementation owns physical source admission -> original stationary row evaluation -> actual scalar load sample -> RigidDynamicsInput with selected gravity/applied contribution -> real rigid assembly -> constrained acceleration -> original source/momentum association. Active derivative, zero-equilibrium proof and new-load wake all call this same operation. Snapshot and inertias use actual public compiled-tree order. Each call uses one execution lease; its local LoadWork spans scalar evaluation and rigid gravity evaluation and is finalized on every success/failure. NumericalWork remains a separately guarded caller ledger; no LoadWork units are substituted for numerical arithmetic. Shared producer errors keep original unavailable-work/cancellation evidence. Concrete actual Loaded motion is required after wake; no delegate-only result or cached derivative can qualify it.

The source, sampled loads/input, system/rows and result association are noninline phases; only immutable bounded context outputs cross phases. Rich completed/future values do not remain live over lower solver calls. The load-work protocol, finite K/bounds, receipt and synchronization guarantees are owned by [StationaryLoads](../StationaryLoads/DESIGN.md), not repeated here. Loaded constraints remain stationary scalar affine; nonlinear/floating/planar/time-varying loads remain unsupported. Changes affect SleepContinuation's AF23 proof/wake and original-profile integration; no frozen lower dynamics or constraint producer change is proposed.

The AF23 implementation provides an additive `StationaryAffineMechanismEquation` facade over the same `AffineMechanismEquation` original row/input/assembly/solver phases. Its loaded chart includes the stronger physical-source signature defined by StationaryLoads. Original zero-load chart bytes remain untouched. The additive facade and original equation expose protocol requirements; checkpoint proof enters a genuine source-bound loaded operation without constructing Runtime controls. Catalog selection remains immutable per adapter, and explicit operation execution owns load accounting.

### Loaded whole-budget numerical invocation envelope
The shared loaded solve partitions the remaining arithmetic and iteration allowance into four disjoint equal integer slices before creating its outer/dynamics/rank/linear ledgers; unused remainder is not executed. Each slice admits its existing nonzero marker before supplier invocation. Their combined actual work therefore cannot execute past the caller's remaining numerical allowance, including failures. The legacy zero-load path preserves its existing allocation contract. Loaded checkpoint validation first removes record/source and logical load reservations, then uses this bounded numerical path. Actual Runtime evidence counts byte/source validation units, numerical arithmetic units, and logical load units; iteration limits separately bound iterative control and do not fabricate arithmetic units.

Cold required validation reuses the loaded owner's immutable initial mechanical configuration. A second `StationaryAffineMotionComputing.loadedMotion` requirement takes an explicit finite n-coordinate constant drive; both overloads enter the same original affine loaded physics, and original solver acceptance checks the actual supplied drive. This computational port does not change the captured SmoothODE descriptor. Accepted command history supplies the drive authority. It prevents canonical descriptor/inertia reconstruction and its uncharged transient metadata allocation inside cold Runtime validation. Source-bound catalog/model/signature admission occurred at owner construction; restored required records still compare that full signature and actual model before consuming this port.
