# MechanicsRuntime

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own revision-bound accepted/trial state, contributor checkpoint, rollback and execution lifetime. IM08 retains its entire requirement family; an accurately declared initial producer handoff does not close all eventual domains. [SPEC](../../SPEC.md) owns requirements and [plan](../../IMPLEMENTATION_PLAN.md) owns dependencies. Children: [StateRecords](StateRecords/DESIGN.md), [Transactions](Transactions/DESIGN.md), [Checkpoints](Checkpoints/DESIGN.md), [Sessions](Sessions/DESIGN.md), [ExecutionEvidence](ExecutionEvidence/DESIGN.md).

## Responsibilities and Boundaries
Numerical integration, dynamics, controllers and observations consume this transaction boundary; they retain their equation and physical semantics. The worker owns child component directories and corresponding tests; root owns this module index, package registration, global probes and progress. Public service operations are protocol requirements. No unavailable physics or continuation state is replaced by successful default data.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Compiler dependency Joints](../MechanicsJoints/DESIGN.md) | depends on | Raw q/v state and fixed-anchor convention | Actual Compiler state values | Dynamic moving anchors remain separately qualified |
| [StateRecords](StateRecords/DESIGN.md) | child | Accepted physical/contributor/random state and capacities | Independent implementation owner | Child contract is authoritative; evidence awaits actual verification |
| [Transactions](Transactions/DESIGN.md) | child | Exclusive trial and cooperative safe points | Independent implementation owner | Child contract is authoritative; evidence awaits actual verification |
| [Checkpoints](Checkpoints/DESIGN.md) | child | Bounded checkpoint admission and continuation | Independent implementation owner | Child contract is authoritative; evidence awaits actual verification |
| [Sessions](Sessions/DESIGN.md) | child | Revision-bound serialized owner and release lifecycle | Independent implementation owner | Child contract is authoritative; evidence awaits actual verification |
| [ExecutionEvidence](ExecutionEvidence/DESIGN.md) | child | Admitted determinism, independent batches and measurement availability | Independent implementation owner | Child contract is authoritative; evidence awaits actual verification |
| [Root](../../DESIGN.md) | parent | Dispatch and global invariants | Composition authority | Full closure remains IM48 |
| [MechanicsCompiler](../MechanicsCompiler/DESIGN.md) | depends on | Immutable compiled identity/revision, actual q/v layout and state validation | Verified producer | Declared descriptor capability is distinct from execution qualification |
| [Core](../MechanicsCore/DESIGN.md) | depends on | Units, finite vectors/transforms and typed errors | Physical and validation values | Frame and dimensional semantics remain explicit |

## Architecture
```text
verified producer values -> bounded validated operation inputs
 -> child-owned actual transaction or constitutive algorithm
 -> independently accepted evidence or typed failure
```

## Contracts and Invariants
Admission/domain, revision/frame/layout association, output semantics, resource accounting and failure visibility are established by actual child contracts before implementation. Immutable records may be shared. Mutable state must have one owner and an identical storage/isolation/Sendable contract across Native, WASM and Embedded. Cross-target qualification needs exact toolchain/SDK compile, link and actual applicable behavior; absence of target proof is explicit.

## State, Ownership, and Lifecycle
Runtime state, contributor state and reserved workspaces belong to their declared state owner; trial state cannot mutate accepted state before commit. Constitutive histories are explicit caller-owned values, not hidden global caches. Actor isolates suspending/ordered complex execution; Mutex protects short synchronous shared metadata. External callbacks and I/O execute outside critical sections. Borrowed views must retain their owner or remain scoped. Ownership and lifetime are detailed by the child that creates/releases each resource.

## Failure, Concurrency, and Constraints
Revision/layout/domain/capacity/nonfinite/unsupported/cancellation failures are typed and transactional within the declared boundary. Limits are caller selected and checked before unbounded traversal/allocation. No unprotected Embedded mutable branch or target-dependent weakened Sendable contract is admitted.

## Verification and Change Impact
Required initial proof: Independent states; actual contributor trial/accept/reject/restart; failure/cancellation retaining the last accepted prefix; shutdown and reentry; selected target synchronization/lifetime. Test owner is Tests/MechanicsRuntimeTests once actual sources exist. Root separately composes selected exact-profile runtime evidence. Consumer changes in transaction/state continuation or framed physical law semantics invalidate their dependent integrator/contact/actuation/control/observation evidence.
