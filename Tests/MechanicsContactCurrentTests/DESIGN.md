# Current contact sampling verification

## Purpose and Scope
Test owner for [Sampling](../../Sources/SwiftMechanics/Physics/ContactLaws/Sampling/DESIGN.md). Parent is the production contract; children: none. Thirteen behavioral cases passed selected independent Native execution. Canonical and original exact-profile qualification remain parent-owned and pending.

## Responsibilities and Boundaries
Independent scalar, derivative, framed power and immutable-history oracles exercise the required service. Fixtures obtain pairs and history through real public pairing and compliant evaluation. No helper fabricates issued history or simulates current sampling with dt=epsilon. Evolution, runtime acceptance and dynamic contact response remain consumer obligations.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Sampling](../../Sources/SwiftMechanics/Physics/ContactLaws/Sampling/DESIGN.md) | depends on | Current accepted-state sample | Subject under test | Static admitted elastic traction only |
| [Response](../../Sources/SwiftMechanics/Physics/ContactLaws/Response/DESIGN.md) | depends on | Issued accepted history | Actual trial provider | Sampling must leave it unchanged |
| [Existing tests](../MechanicsContactLawsTests/DESIGN.md) | coordinates with | Original shared-kernel regression | Existing law preservation | Re-run affected tests after extraction |

## Architecture
```text
public material pairing + public history issuance
 -> required current sampler
 -> independent scalar/power/rotation/derivative assertions
 -> refusal + unchanged accepted-history checks
```

## Contracts and Invariants
Float64 SI fixtures use explicit caller tolerances. The linear analytic pair has k=1000 N/m and kt=1000 N/m. At s=-0.01 m and zero vn, Fn=10 N and Un=0.05 J. A real trial issued with vt=1 m/s and dt=0.001 s produces z=0.001 m; a current sample must return Ft=-1 N and Ut=0.0005 J, independently of current tangential velocity, while retaining the exact sequence/time/bristles/cumulative discrete loss. Virgin zero history permits arbitrary valid slip. Reduced Fn=2 N with issued z=0.005 m must refuse the static bound 1.6 N rather than return-map 5 N traction; open Fn=0 with nonzero z must refuse rather than release its energy.

Analytic rolling/spin couples and their regularized angular partials are checked independently, including finite-difference directional checks inside the smooth domain. A rotated anisotropic basis must rotate force/couple while preserving scalar potentials and global/local power. Normal clipping, linear/Hertz/HC branches and reversible cohesive opening use original equations; rate balance and scalar power are checked independently. Changed time, identity, revision/frame/material pair, normal envelope, huge arithmetic, long metadata, operation/storage/record capacity and cancellation must produce exact typed failures with unchanged accepted values.

## State, Ownership, and Lifecycle
Each test owns local immutable pair/history/input and exclusive ContactWork. There is no shared mutable fixture, file, random state, hidden cache or platform conditional storage. Cancellation tests use their own Task; target concurrency proof is limited to the actually executed platform.

## Failure, Concurrency, and Constraints
Root authorizes and coordinates registration/profile composition. After source confirmation, independent Native qualification uses immutable baseline 3fe26e1 plus only this owner overlay and affected existing tests, Swift 6.4.0 RELEASE, four build jobs, setup timeout 1200 seconds and behavior timeout 240 seconds. A new copy is deferred until root confirms disk capacity. No canonical manifest or supplier test edits are required.

## Verification and Change Impact
Run new current tests and affected original ContactLaws tests against the same stable shared-kernel source. Their evidence covers selected constitutive sampling and original trial regression, not upper structural/CAD evolution. The immutable 3fe26e1 proof with the owned overlay compiled/linked under Swift 6.4.0 RELEASE and passed all thirteen Current cases plus nineteen original ContactLaws cases. Evidence is [setup](../../.build/af29-independent-current/setup.log) and [behavior](../../.build/af29-independent-current/tests.log); no supplier test source was changed. Root owns original Native/WASM/Embedded external required-operation probes and parent evidence. A changed shared equation or history association invalidates both owners' affected evidence; derivative-only Sampling changes affect its derivative proof without broadening original Response behavior.
