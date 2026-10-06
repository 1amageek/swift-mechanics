# ContactLaws component

## Purpose and Scope
Parent: [responsibility owner](../DESIGN.md). Own constitutive normal, friction, rolling/spinning, cohesion and material-pair meaning. IM20 retains its entire requirement family; an accurately declared initial producer handoff does not close all eventual domains. [SPEC](../../../../SPEC.md) owns requirements and [plan](../../../../IMPLEMENTATION_PLAN.md) owns dependencies. Children: [Inputs](Inputs/DESIGN.md), [MaterialPairs](MaterialPairs/DESIGN.md), [Response](Response/DESIGN.md), [Impact](Impact/DESIGN.md), [Sampling](Sampling/DESIGN.md).

## Responsibilities and Boundaries
Collision owns geometric witnesses; IM21 translates witnesses into these minimal framed inputs and solves coupled response; IM24 owns accepted impact evolution. The worker owns child component directories and corresponding tests; root owns this module index, package registration, global probes and progress. Public service operations are protocol requirements. No unavailable physics or continuation state is replaced by successful default data.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Inputs](Inputs/DESIGN.md) | child | Framed separation/velocity/history admission and work | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [MaterialPairs](MaterialPairs/DESIGN.md) | child | Material pairing, calibration and loss policy | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [Response](Response/DESIGN.md) | child | Compliant normal/friction/resistance/cohesion response | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [Sampling](Sampling/DESIGN.md) | child | Instantaneous original force/energy at issued accepted history | Prerequisite for material tooth evolution | No history advancement, inferred sliding mode or manufactured time step |
| [Impact](Impact/DESIGN.md) | child | Threshold restitution prediction from declared approach speed and energy | Independent implementation owner | Child contract is authoritative; admitted proof is recorded below |
| [Responsibility owner](../DESIGN.md) | parent | Dispatch and global invariants | Composition authority | Full closure remains IM48 |
| [MechanicsModel](../../Modeling/Model/DESIGN.md) | depends on | Entity/frame/material identity; Core SI/framed geometry | Verified producer | Declared descriptor capability is distinct from execution qualification |
| [Core](../../Mathematics/Core/DESIGN.md) | depends on | Units, finite vectors/transforms and typed errors | Physical and validation values | Frame and dimensional semantics remain explicit |

## Architecture
```text
verified producer values -> bounded validated operation inputs
 -> child-owned actual transaction or constitutive algorithm
 -> independently accepted evidence or typed failure
issued history + current input -> Sampling -> unchanged-history current force/energy
```

## Contracts and Invariants
Admission/domain, revision/frame/layout association, output semantics, resource accounting and failure visibility are established by actual child contracts before implementation. Immutable records may be shared. Mutable state must have one owner and an identical storage/isolation/Sendable contract across Native, WASM and Embedded. Cross-target qualification needs exact toolchain/SDK compile, link and actual applicable behavior; absence of target proof is explicit.

## State, Ownership, and Lifecycle
Runtime state, contributor state and reserved workspaces belong to their declared state owner; trial state cannot mutate accepted state before commit. Constitutive histories are explicit caller-owned values, not hidden global caches. Actor isolates suspending/ordered complex execution; Mutex protects short synchronous shared metadata. External callbacks and I/O execute outside critical sections. Borrowed views must retain their owner or remain scoped. Ownership and lifetime are detailed by the child that creates/releases each resource.

## Failure, Concurrency, and Constraints
Revision/layout/domain/capacity/nonfinite/unsupported/cancellation failures are typed and transactional within the declared boundary. Limits are caller selected and checked before unbounded traversal/allocation. No unprotected Embedded mutable branch or target-dependent weakened Sendable contract is admitted.

## Verification and Change Impact
Required initial proof: Independent force curves, rotation covariance, dissipation and separation energy; explicit incompatible model/restitution/material policy and budget failures. Test owner is Tests/MechanicsContactLawsTests once actual sources exist. Root separately composes selected exact-profile runtime evidence. Consumer changes in transaction/state continuation or framed physical law semantics invalidate their dependent integrator/contact/actuation/control/observation evidence.

### Verified initial producer handoff
The registered Native package passed all 154 behavioral tests, including this owner’s fourteen tests. Actual pairing, compliant response, history rollback/release, anisotropic friction return, resistance, cohesive separation, threshold restitution, metadata budgets and typed failures execute through required service methods. Each child owns its precise law, energy/power convention, admission and resource accounting. In particular the tangential return is a declared spring regularization, not an exact maximum-dissipation Coulomb solve.

The selected public-service probe in [FoundationVerification](../../../../Verification/FoundationVerification/DESIGN.md) separately compiled, linked and ran with exit 0 on installed Swift 6.4.0 release Native arm64 macOS 27, swift-6.4.0-RELEASE_wasm and swift-6.4.0-RELEASE_wasm-embedded with --traits EmbeddedUnicode. Node.js 24.19.0 WASI Preview 1 executed both WASM artifacts. Independent linear/Hertz/Hunt-Crossley force/energy/power, tangent history/ellipse/dissipation, resistance/cohesion, restitution and stale/loss-policy failures passed. Native Task cancellation is not generalized to WASI parallel execution. Coupled response, physical exact Coulomb, accepted impact/evolution, drop/time convergence, irreversible cohesion and additional constitutive families remain separate unqualified obligations.

### AF14 material-site prerequisite handoff
Inputs owns the body-scoped ordered material-site extension and its immutable all-target owner. Nineteen Native constitutive tests passed (fourteen original plus five site-specific); a focused independently reconstructed identity/replay check supplements the owned-record correction. Eleven Native ContactResponse cases passed, including explicit rejection of nodal site representation before rigid mass/cone/law work. Final original Native, ordinary WASM and Embedded public artifacts each exited 0 using exact Swift6.4.0 release/matching SDKs, EmbeddedUnicode and Node24.19.0 WASI Preview1. Selected same-body friction force/energy/power, immutable replay and stale site revision actually executed. The original distinct-body paths also executed. Full self-surface geometry, nodal integration/impacts and FX009 require the downstream actual geometry/force path. No private stack diagnostic supplies platform qualification.

### Consolidation contract
This directory is a component inside the SwiftMechanics module, not a separate SwiftPM target. Its existing public behavior and exact-profile evidence remain its contract authority. Cross-component access uses the documented contracts; internal visibility alone does not grant admission or publication authority. Source relocation requires integrated behavioral requalification.

### AF29 current-sampling prerequisite

linear_kernels exclusively owns Sampling, its dedicated tests and the necessary Response pure-kernel extraction documented by those children. The accepted instantaneous sampling contract is authorized for implementation; original trial arithmetic, failure order, work and issued history remain regression obligations. Root owns parent registration and profile/public qualification. Material tooth evolution requires a qualified lower handoff before implementation. Supplier-owned current sampling does not itself certify upper dynamics or accepted evolution.

Selected AF29 Sampling and unchanged original trial semantics passed the [integrated lower evidence](../../../../Verification/FoundationVerification/DESIGN.md#af29-qualified-current-sampling-prerequisite). The additive required operation now supplies the material tooth prerequisite. Exact full source/time/pair, held bristles, force/couple/potential, rate power and typed inconsistent-history refusal are qualified in the executed profiles; upper evolution remains its own proof obligation.
