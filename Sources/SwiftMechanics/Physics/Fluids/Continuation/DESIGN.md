# Continuation

## Purpose and Scope
Initial admitted implementation domain; behavioral/profile qualification pending. Parent [Fluids](../DESIGN.md); no children. Own bounded same-context versioned fluid contributor payload, required Runtime validation and actual fluid trial time evolution. General model migration is an explicitly failed deferred callable path.

## Responsibilities and Boundaries
Codec is pure memory, no filesystem/network/Runtime checkpoint schema duplication. Runtime checkpoint codec owns enclosing checksum/physical carrier/continuation. Fluid contributes separately owned u/pressure/boundary/time/sequence under category integrator and a distinct caller id; this does not claim generic mechanical ODE integration. Runtime carrier must be fixed world-frame, empty q/v; it supplies time/lifecycle and does not receive invented rigid fluid coordinates or forces.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Channel](../ChannelDiscretization/DESIGN.md) | depends on | complete physical signature/state | Identity includes units/layout/physics |
| [Evolution](../ViscousEvolution/DESIGN.md) | depends on | actual BE operation and original evidence | No success from codec alone |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | depends on | required contributors, trial/control, checkpoint handler/session | Validation has no physical-time argument; trial association required |
| [Compiler](../../../Modeling/Compiler/DESIGN.md) | depends on | model stamp, fixed carrier descriptor | Model changes rejected, not guessed compatible |

## Architecture
```text
bounded context -> versioned fluid record -> Runtime admission/checkpoint
Runtime.performTrial -> decode + full time/model/frame association -> actual BE
 -> final safe point -> replace record + advance time -> accept/reject
```

## Contracts and Invariants
Codec version1 fixed little-endian UInt64/Double IEEE754 fields, byte-exact bounded UTF8 context signature for channel/model/frame/source/boundary-law/contributor ids and all revisions, layout and physical/envelope scalars. Header is compared against owned expected bytes; untrusted bytes never create String or silently normalize Unicode. Same semantic Unicode aliases with different UTF8 are intentionally different wire bindings. Exact size rejects truncation/trailing/oversize, magic/version/reserved or any changed physical signature. Dynamic portion has time, sequence, boundary4scalars, n velocities and n+1 pressures, all original state domains revalidated. Incoming contributor identity is traversed with a bounded byte ledger before semantic comparison; caller metadata/byte bounds checked before copying/traversing; codec reports byte work/scratch separately from NumericalWork. Pressure faces must match hydrostatic recurrence within declared original tolerance. Restored history is immutable state; Runtime independently restores full checkpoint. Codec payload validation proves local state, not physical-time association. Actual trial operation checks payload.time==trial.timeSeconds and supplied model/full context fixed-frame binding before advancing. Reject and failure never modify accepted prefix; accepted fluid time equals carrier time.

## Runtime Flows
Trial operator is a required protocol operation over inout RuntimeTrial/RuntimeStepControl and NumericalWork, invoked inside real Runtime.performTrial by caller. Safe points charge four units total, one per bounded phase (decode, solve, encode, final publication), explicitly logical phases rather than guessed FLOPs. maxCells and numerical budget bound synchronous phase size; no interruptible supplier claim. Runtime cancellation is rechecked immediately after actual solve and before publication. Pure solver also has caller cancellation hook. Caller owns accept/reject decision. Checkpoint/restart use real NativeRuntimeCheckpointCodec and contributor validation; no hidden mutable capture. The test cancellation owner uses the same Mutex on all targets. Byte ledger counts visited wire bytes and logical live storage, not allocator capacity or numerical FLOPs.

## State, Ownership, and Lifecycle
Codec/context/provider immutable Sendable; buffers call-local; trial exclusively borrowed. All public operations are protocol requirements. No shared production mutable state. Runtime availability propagated macOS15/iOS18/tvOS18/watchOS11. Same storage/conformance/isolation across profiles. Failed solver work unavailable remains explicit through FluidError; Runtime typed failure maps category without false accepted result and retains any numerical failedSupplierWorkUnavailable flag through RuntimeFailure and accepted-prefix retention. Caller retaining NumericalWork outside closure must use a synchronized capture if shared.

## Failure, Concurrency, and Constraints
Typed codec capacity/stale/invalid/nonfinite and Runtime contributor/state/time/budget failures. Migration required by Runtime is marked INCOMPLETE and throws unsupportedDomain: changed model fluid reconciliation is unqualified. Required contributor bytes and validation work/scratch are caller admitted. No hidden reset or fallback.

## Verification and Change Impact
[Tests](../../../../../Tests/MechanicsFluidsTests/DESIGN.md) execute actual accepted evolution, rejection/failure rollback, payload-time mismatch, checkpoint/restart replay and stale/corrupt/truncated/oversized records, cancellation and capacities. Changes to signature/physics require version change and replay tests; Runtime producer changes require root additive coordination. Native/profile qualification remains pending root execution.
