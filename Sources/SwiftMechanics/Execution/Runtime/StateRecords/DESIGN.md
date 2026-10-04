# Runtime State Records

## Purpose and Scope
Own immutable accepted/checkpoint records, explicit capacity and continuation identity, contributor schema completeness and SplitMix64 random continuation. Parent: [MechanicsRuntime](../DESIGN.md). No children.

## Responsibilities and Boundaries
Compiler owns model/chart validity. Runtime records own model stamp, accepted sequence, time/q/v/vdot, random seed/state/draw count and every explicitly required contributor payload. No implicit actuator/controller/event/warm-start/integrator state is generated.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Runtime](../DESIGN.md) | parent | Initial runtime scope | Root composition | Full requirement family remains IM08 |
| [Compiler records](../../../Modeling/Compiler/CompilationRecords/DESIGN.md) | depends on | CompiledKinematicState and immutable model | Actual association and q/v convention | Compiler evidence f96cbdd is not integration physics |

## Architecture
```text
compiled model + explicit configuration + physical/contributor/random values
 -> admitted RuntimeAcceptedState -> immutable observation/checkpoint values
```

## Contracts and Invariants
RuntimeAcceptedState consumes the immutable checkpoint publication token issued only by ReferenceRuntimeCheckpointHandler's file after full admission. Shared-module internal visibility grants no raw-state construction authority. Its public observations expose accepted data without exposing the token.

`RuntimeModelReplacement` is an immutable retained request carrying source checkpoint and explicit target data; Sessions owns compatibility and publication. It does not invent a physical state transfer, certify a joint break or automatically migrate contributor history. The target handler is retained through the session's immutable context after success. All records remain Sendable on the same target boundaries.
Initial domain is synchronous kinematic-state transactions for the actual compiler's connected planar/spatial trees, fixed anchor placement and Float64 reference CPU state. Prescribed moving-anchor derivative serialization is explicitly unsupported in this initial handoff; root floating charts (including spatial q7/v6) are supported. Physical time is SI seconds, q/v/framed convention belongs to Compiler/Joints. Accepted state is immutable and only a fully validated checkpoint can create it. Required schemas cover every caller-owned stateful contributor (actuator/controller/event/random/warmStart/integrator/constitutive/backend/observation); built-in physical/random state is always explicit. Application/provider owns declaring all state it uses; declaring an empty list never qualifies unknown dynamics or external internal state.

Capacity includes physical scalars, contributor count/bytes, metadata/checkpoint bytes, validation work, operation count, observation leases, batch states and step work/safe-point quantum. Nonnegative caller-selected limits are not guessed platform tolerances. Counts/products/UInt64 continuation counters are checked; integer RNG mixing intentionally uses published wrapping UInt64 arithmetic. Raw restored RNG state must equal seed + draws*increment modulo 2^64; inconsistent continuation is corrupt data. No shared mutable reference occurs in accepted values.

## State, Ownership, and Lifecycle
Immutable records are Sendable value owners. Mutable work lives in an exclusive inout transaction; shared metadata/cancellation state uses identical Mutex storage on every target. Native/WASM/Embedded semantics are qualified only by selected actual target paths.

## Failure, Concurrency, and Constraints
Typed RuntimeFailure identifies domain, missing contributor, incompatible model/continuation, capacity, busy/closed/cancelled or validation failure. Session failures retain last accepted prefix. RuntimeFailure.failedSupplierWorkUnavailable preserves an explicitly reported unknown nested supplier ledger through diagnostic bounding and prefix retention; false does not certify all provider work by itself. Limits precede allocation and publication is all-or-nothing. No silent fallback or unimplemented success.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsRuntimeTests/DESIGN.md): Independent states, q7/v6 layout, required/missing contributor, seeded rollback and finite/capacity failure fixtures. Changes affect Transactions, Checkpoints, Sessions and downstream state providers.
