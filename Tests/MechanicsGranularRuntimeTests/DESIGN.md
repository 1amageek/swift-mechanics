# Granular Runtime behavioral proof

## Purpose and Scope
Parent [package](../../DESIGN.md), no children. Own selected accepted granular Runtime history/RNG and bounded cold journal proof.

## Responsibilities and Boundaries
Exercise actual public Runtime transactions and original particle evolution. Fixtures freshly prepare source/models; they do not manufacture histories. Root owns canonical graph/profile/commit evidence.

## Related Designs
| Design | Relationship | Contract used | Caution |
|---|---|---|---|
| [RuntimeContinuation](../../Sources/SwiftMechanics/Physics/Granular/RuntimeContinuation/DESIGN.md) | verifies | Source/journal/trial/checkpoint authority | Bounded accepted-step journal only |
| [ParticleEvolution](../../Sources/SwiftMechanics/Physics/Granular/ParticleEvolution/DESIGN.md) | depends on | Original sphere/plane physics | Independent impulse/torque/work oracle |
| [Runtime](../../Sources/SwiftMechanics/Execution/Runtime/DESIGN.md) | depends on | Accepted publication/rejection/restart | Fresh owners, real checkpoint bytes |

## Architecture
```text
fresh seed recipe -> actual Runtime trial -> original physical state
 -> reject/no publication -> accept/history+RNG publication
 -> wire checkpoint -> fresh source/contributor/session -> original replay -> exact continued result
```

## Contracts and Invariants
Verify every motion/history/basis/time/sequence/RNG field, original physical evidence and actual contributor bytes. Changed source/policy/state and forged journal metadata must fail before Runtime publication. Runtime snapshots remain equal after rejection/failure. Test suppliers perform actual producer work before failure or ledger reset.

## Verification and Change Impact
Fixed-toolchain Native tests run with timeouts in `.build/af27-independent-granular-runtime` against baseline `1bf65c3`, overlaying only owned directories and copy-only affected test registration. Root later validates canonical integration and public profiles. Existing producer tests are unchanged; no evidence is inferred from compilation or structure.

Actual isolated Native setup and execution used Swift 6.4.0 RELEASE, four build jobs, a 1,200-second setup timeout and a 240-second focused timeout. After correcting a test-only value-model identity assertion, setup exited zero. Actual public Runtime/particle physical tests initially passed 12 declarations / 3 suites / 20 expanded cases. The new source-budget regression reproduced caller native-ledger substitution bypass (5,096 operations despite original numerical ceiling zero), then the corrected admission gate passed it together with the complete stable owner suite: 13 declarations / 3 suites / 21 expanded cases, exit zero, runtime 0.015 seconds. Evidence logs are `.build/af27-granular-runtime-native-setup-2.log`, `.build/af27-granular-runtime-native-focused.log`, `.build/af27-granular-runtime-budget-red.log` and `.build/af27-granular-runtime-budget-green.log`. The regression verifies staleSource before any native operation. No additional producer hardening or profile qualification is implied.
