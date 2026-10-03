# MechanicsContactLaws

## Purpose and Scope
Parent: [system/package](../../DESIGN.md). Own constitutive normal, friction, rolling/spinning, cohesion and material-pair meaning. IM20 retains its entire requirement family; an accurately declared initial producer handoff does not close all eventual domains. [SPEC](../../SPEC.md) owns requirements and [plan](../../IMPLEMENTATION_PLAN.md) owns dependencies. Children are indexed when their actual contracts exist.

## Responsibilities and Boundaries
Collision owns geometric witnesses; IM21 translates witnesses into these minimal framed inputs and solves coupled response; IM24 owns accepted impact evolution. The worker owns child component directories and corresponding tests; root owns this module index, package registration, global probes and progress. Public service operations are protocol requirements. No unavailable physics or continuation state is replaced by successful default data.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Root](../../DESIGN.md) | parent | Dispatch and global invariants | Composition authority | Full closure remains IM48 |
| [MechanicsModel](../MechanicsModel/DESIGN.md) | depends on | Entity/frame/material identity; Core SI/framed geometry | Verified producer | Declared descriptor capability is distinct from execution qualification |
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
Required initial proof: Independent force curves, rotation covariance, dissipation and separation energy; explicit incompatible model/restitution/material policy and budget failures. Test owner is Tests/MechanicsContactLawsTests once actual sources exist. Root separately composes selected exact-profile runtime evidence. Consumer changes in transaction/state continuation or framed physical law semantics invalidate their dependent integrator/contact/actuation/control/observation evidence.
