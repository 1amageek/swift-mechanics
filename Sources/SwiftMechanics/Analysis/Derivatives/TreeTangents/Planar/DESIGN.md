# Planar Tree Tangents

## Purpose and Scope
Parent: [TreeTangents](../DESIGN.md). Children: none. Own OP-001/OP-002 instantaneous analytic directional products for planar body trees with fixed or planar floating roots. This is a lower tree contract, not complete IM30 dynamics or full210 qualification.

## Responsibilities and Boundaries
`ExactPlanarTreeDifferentiator` implements the existing `TreeDifferentiating` protocol. It differentiates the actual supplier's ordered translation/rotation factors and frame composition. Root reference pose and fixed anchors are immutable. Prescribed samples require explicit directions; time direction denotes the supplied instantaneous full-motion direction and does not infer jerk or a time law. Spatial bodies, spatial floating roots, out-of-plane sample directions, and nonzero screw-pitch directions fail `derivativeUnavailable`.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [TreeTangents](../DESIGN.md) | parent | TreeDifferentiating, TreeDirection, TreeTangent, checked directional algebra | Existing public layout and publication | Preserve actual nonzero generalized acceleration |
| [ArticulatedTrees](../../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | TreeKinematicsEvaluator, KinematicSnapshot | Original primal and world-frame geometric columns | Supplier failure retains typed cause and charged call |
| [JointManifolds](../../../../Modeling/Joints/JointManifolds/DESIGN.md) | depends on | orderedAxes, preservesWorldXYPlane | Planar root is X/Y translation then Z rotation | Three position and three velocity coordinates |
| [Tests](../../../../../../Tests/MechanicsPlanarTreeDerivativeTests/DESIGN.md) | used by | public provider | Independent finite differences and exact physical fixture | Finite differences exist only in tests |

## Architecture
```text
planar tree + state + public direction + exclusive workspace
    -> bounded admission -> original TreeKinematicsEvaluator snapshot
    -> checked ordered-factor differential frame recurrence
    -> original pose/motion/column comparison -> immutable TreeTangent
```

## Contracts and Invariants
Configuration direction uses velocity layout: metres for translations and radians for rotations. Planar floating storage and tangent have `(x,y,theta)` order; coordinate-rate direction equals velocity direction. Geometric columns are world angular/linear velocity at each body origin. Rotation direction is a matrix product for the existing right-body rotation tangent. Branch children inherit only their ancestors' columns. Actual velocity and acceleration are independent inputs. Acceleration bias direction is `d(actual acceleration)-dJ*a-J*da`; prescribed drift direction is `d(actual velocity)-dJ*v-J*dv`. The original snapshot is produced from the same tree and state and every reconstructed primal pose, motion and column is checked before publication. No finite difference or alternate primal is used in production.

## Runtime Flows
Check cancellation, revision, shape, dimension, capacities and finite directions; validate planar sample directions and pitch directions; precharge storage and all supplied identity bytes; charge and invoke the original supplier once. Compose root and child frames in topology order using the verified parent index. Build fixed-size local factors and flat body/velocity columns. Charge each public snapshot column lookup, compare all reconstructed primal values, compute bias/drift and publish only after a final cancellation check.

## State, Ownership, and Lifecycle
Caller-exclusive `TreeTangentWorkspace` owns mutable frames, columns, prefixes and factor columns. It has identical Sendable and storage semantics on Native, ordinary WASM and Embedded. No target branch removes isolation or changes state ownership. Output owns its immutable arrays and prior results remain valid when scratch is reused. The conservative logical scalar storage requirement is `400*B+48*B*N+1440+retained initialized workspace slots`, shared with the parent's verified ownership calculation. This includes primal/output/frame/column owners and six-factor scratch, not allocator rounding or unused retained capacity. No pointers or borrowed views escape.

## Failure, Concurrency, and Constraints
Stale revision, shape, unsupported domain, nonfinite inputs/results, cancellation, capacity, operation/storage budgets, original supplier errors and primal mismatch fail typed. Numerical operations and public supplier calls are distinct ledgers; supplier internal arithmetic remains unavailable. The tree constructor owns topology and planar fixed-anchor admission. No shared mutable state, static cache or target-dependent synchronization exists.

## Verification and Change Impact
Native tests compare translation, rotation matrix, actual velocity/acceleration, bias/drift, coordinate rates and every geometric column against independent central differences through the original primal supplier for fixed/floating, serial/branch and prescribed fixtures with nonzero acceleration. An exact hinge-offset fixture independently checks physical velocity, centripetal bias and their derivatives. Failure fixtures check stale/shape/nonfinite/nonplanar direction, actual missing supplier sample, cancellation, capacity, numerical/storage/supplier budgets and retained scratch. Raw public existential invocation on matching Swift 6.4.0 Native/WASM/Embedded with the unchanged 131072 stack guard qualifies only this lower path. Parent qualification and mechanical composition remain separately owned.

### Native qualification
The frozen Native-only private graph passed all 12 tests in two suites with Swift 6.4.0 release on arm64 macOS. Setup took 268.604 seconds (tool report 258.90), and the separate 240-second-watchdog runtime exited zero in 15.266 seconds; Swift Testing reported 0.024 seconds. The original 1559 production/test source hashes and private manifest were unchanged across setup and behavior. Actual compiler source list, output map, provider object, direction symbol, link list and test executable were matched and hashed in `.build/planar-proof/native-receipt.json`. The private graph removed 54 unrelated test targets while preserving production/executable target dependencies and flags. This evidence qualifies only this lower Native provider and the exercised fixtures. Original public ordinary/Embedded WASM execution and the 131072-byte stack guard remain open; full IM30 and full210 are not claimed.
