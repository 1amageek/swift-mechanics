# GeometricRelations

## Purpose and Scope
Parent: [Constraints](../DESIGN.md). No children. Own immutable identified holonomic point coincidence, distance and axis-alignment equations evaluated on actual compiled spatial tree body/frame geometry. This is the lower IM16.9 contribution to CN001/004/006/007; time evolution remains an upper consumer responsibility.

## Responsibilities and Boundaries
Own analytic target records, bounded canonical equation metadata, dimensionless tangent rows, original scalar geometry acceptance, source/domain validation and numerical work. Joints owns actual manifold kinematics. Dynamics owns mass, force, reaction and physical energy. No force or accepted Runtime state is inferred here. Literal disconnected/multiple-root trees, planar/spatial mixed bodies and prescribed frames remain explicit unsupported domains. The public evaluator protocol contains every existential operation as a requirement.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Constraints](../DESIGN.md) | parent | Requirement owner/index | Direct requirement/design owner | Root updates registration |
| [Joints](../../../Modeling/Joints/DESIGN.md) | depends on | Compiled snapshot, point Jacobian/motion, public body/frame/column access | Lower producer consumed by this component | No internal tree storage |
| [CoordinateEquations](../CoordinateEquations/DESIGN.md) | depends on | VelocityConstraintSample, layout, policy | Lower producer consumed by this component | Tangent columns are nv, not nq |
| [ManifoldProjection](../ManifoldProjection/DESIGN.md) | used by | Evaluation and sealed original acceptance | Consumer of this component | Initial chart must already be valid |
| [Tests](../../../../../Tests/MechanicsGeometricConstraintTests/DESIGN.md) | used by | Independent physical oracles | Consumer of this component | Root owns platform qualification |

## Architecture
```text
immutable compiled model + identified frame records + analytic target/domain
 -> bounded admission -> actual tree snapshot
 -> public point Jacobian/motion -> g, A, drift, bias
 -> independent original body-column geometry acceptance
 -> immutable sample or typed failure
```

## Contracts and Invariants
State q/v/time is SI; layout scales S and time T identify tangent coordinates. Rows satisfy dg/dt=(A*(v*T/S)+drift)/T and d2g/dt2=(A*(a*T*T/S)+bias)/T/T. Coincidence uses physical length scale; distance uses squared-length normalization; alignment uses unit directions. Actual centripetal and tree acceleration bias enter once through point motion. Explicit analytic targets are quadratic polynomials of physical time with exact first/second derivatives, distinguished from autonomous targets in canonical metadata. Fixed named frames resolve against the public tree body's frame or fixed joint anchors and preserve nonidentity local transforms. All original rows and IDs, including redundant zero rows, survive evaluation. Axis alignment declares exactly two original rows: firstAxis dot each of the two orthonormal transverse directions fixed in the second endpoint frame. Their moving-direction product derivatives supply exact tangent, drift and acceleration bias. The same/opposite hemisphere branch firstAxis dot secondAxis times axisSign > 0 is explicit. A separately retained full physical axis cross residual verifies actual alignment at final feasibility. No original declared row is discarded or rounded. The previous three-cross-component representation was never qualified or released: actual mixed assembly demonstrated off-manifold rank three becoming rank two at alignment, violating constant-rank local assembly. This regular local chart replaces that representation without changing rank producers or tolerances.

Canonical metadata version two includes the two stored frame-local transverse directions and the regular-chart rule. Canonical metadata is bounded before string allocation and includes model descriptor geometry, root/tree layout, coordinate IDs/dimensions/scales, row IDs/kinds/endpoints/local geometry, target coefficients, domains and normalization. Model stamp alone is insufficient. Output source state and snapshot are validated against actual supplied model geometry, body/frame motion and all public columns. A separate builtin original evaluator derives points and directions directly from body transforms/columns; supplied diagnostics never establish original acceptance.

## Runtime Flows
Admission/storage/work reservation precedes lower callbacks. Actual compiled makeState/evaluate is charged by a bounded structural envelope before invocation. Cancellation is checked before and after callbacks and before result publication. Original acceptance recomputes all rows at the supplied state and compares source, values, tangent rows, drift and bias.

## State, Ownership, and Lifecycle
Inputs, metadata and results are immutable Sendable values. Work and buffers are exclusive operation locals. There is no shared mutable state, no target branch and no unsafe storage. Caller-owned immutable arrays retain their backing through value ownership.

## Failure, Concurrency, and Constraints
Typed GeometricConstraintError distinguishes shape/domain/chart/source/original/branch/capacity/cancellation and supplier ledger replacement/unavailable work. Bounds cover bodies, q/v, rows, metadata bytes, numeric storage and arithmetic before allocation/callback. Opaque suppliers in consumers receive seeded ledgers only after irreversible caller admission; success and failure ledger preservation is mandatory, and unknown failed work prohibits retry.

## Verification and Change Impact
Dedicated tests own actual revolute fourbar independent sin/cos g/rate/bias, nonidentity frame offsets, sixDOF/spherical mixed q/v, explicit target derivatives, source/row/diagnostic rejection and capacity/cancellation. Any scale, bias, row or metadata change invalidates ManifoldProjection and future mechanism endpoint/reaction composition evidence.
