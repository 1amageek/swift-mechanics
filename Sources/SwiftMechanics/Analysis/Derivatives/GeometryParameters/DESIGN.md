# Geometry parameter products

## Purpose and Scope
Parent: [Derivatives](../DESIGN.md). Own selected OP-001/002/010 smooth geometric parameter products through actual spatial tree pose, motion, geometric Jacobian and acceleration bias. No children. Initial selected source supports fixed roots, fixed anchors and fixed/single revolute/prismatic/screw joints. Source is excluded and unqualified until later behavioral and target evidence.

## Responsibilities and Boundaries
Own source-bound scalar parameter maps, translation/right-body rotation/normalized raw-axis charts, analytic geometry propagation and original primal acceptance. q, v, generalized acceleration and time are held fixed; these products are parameter derivatives, not configuration derivatives or temporal derivatives. Topology, body modes, inertia, external laws, moving anchors, derived multi-axis charts and floating roots remain separate contracts. No finite difference backend or old supplier internal helper is consumed.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Derivatives](../DESIGN.md) | parent | Smooth derivative ownership | Source-only additive child | Full OP-family remains open |
| [ArticulatedTrees](../../../Modeling/Joints/ArticulatedTrees/DESIGN.md) | depends on | Actual tree layout and public snapshot/columns | Primal authority | Fixed-source topology only |
| [JointManifolds](../../../Modeling/Joints/JointManifolds/DESIGN.md) | depends on | Normalized axis charts and public motion evaluator | Rotation/screw conventions | No use of internal generator/pose |
| [ScalarCalculus](../ScalarCalculus/DESIGN.md) | depends on | Public exact scalar arithmetic | Quaternion axis normalization/trigonometry | No hidden numerical differentiation |
| [TreeTangents](../TreeTangents/DESIGN.md) | coordinates with | Public body/world tangent conventions | Compatible pose/J/bias meaning | Existing products differentiate state, not arbitrary fixed geometry |

## Architecture
```text
immutable original tree + fixed state + model/CAD provenance
  + scalar parameter maps and direction
    -> mapping/source/chart admission -> normalized-axis analytic direction
    -> actual TreeKinematicsEvaluator primal snapshot
    -> owned pose/motion/column analytic recurrence
    -> original pose/motion/J/drift/bias agreement + reconstruction residual
    -> immutable source-bound product or typed failure
```

## Contracts and Invariants
Each binding identifies parameter ID, original scalar SI value/dimension, model provenance and tree revision, parameter provenance, target identity and exact reference chart. Translation parameters have length units and act in the placement's parent frame. Rotation parameters have angle units and use R(lambda)=R0*Exp((lambda-lambda0)*eta), with translation fixed. Normalized raw-axis parameters are dimensionless and use a(lambda)=normalize(r0+(lambda-lambda0)*dr). The scalar direction multiplies the chart's per-unit vector. All chart origins must match actual selected placement or normalized axis; stale sources and unsupported topology fail as derivative unavailable. Two bindings on the same target add their first-order products while preserving separate provenance.

The normalized-axis derivative is da=(dr-a*(a dot dr))/|r|. Scale-normalized evaluation avoids avoidable overflow, and the caller's minimum raw-axis magnitude defines the open differentiability domain; zero or boundary axes fail. The actual axis normalizer in rotation construction is differentiated again, then the public scalar product/trigonometric/square-root/division algebra differentiates the same normalized quaternion and rotation matrix. Parameter nominal values and chart origins are explicit; no CAD value is inferred from a mechanics label.

For each body, compose parent body, fixed parent anchor, actual joint factor and inverse fixed child anchor. Differentiate every frame rotation, offset, angular/linear velocity and acceleration term, including centrifugal and Coriolis cross products. Each actual geometric column propagates parent angular/linear transport and the selected local axis through the parent anchor and child-origin offset. At fixed q/v/a: dDrift=dVelocity-dJ*v and dBias=dAcceleration-dJ*a. Coordinate-rate direction is zero because scalar charts use qdot=v and state is held fixed. No constant-J shortcut is allowed.

Acceptance checks the reconstructed primal against the original public snapshot at every world/body/joint-anchor frame and body/column and original drift/bias. Original residuals separately verify velocity=J*v+drift and acceleration=J*a+bias for primal and directional values. A small residual is a consistency witness, not an independent derivative accuracy oracle; independent analytic/directional differences remain deferred verification. The product retains the exact original tree/state/model and parameter provenance, frame/layout/revision, bindings, normalized-axis directions and acceptance witnesses. Constructors of accepted products are internal. No successful result represents a topology derivative or a substituted source. Model/CAD provenance is caller-declared immutable mapping authority; this operation verifies reference-chart agreement with the retained actual mechanics source and does not infer or query an external CAD revision.

## Runtime Flows
Validate capacities, finite state/directions, source mapping and supported topology; precharge identity/provenance bytes; reserve all simultaneous scalar owners before allocation. Resolve bindings into local placement/axis directions; call the concrete primal supplier once; propagate frame/column jets in tree order; compare original primal fields and reconstruct original equations; publish only after final cancellation. No retries or perturbed primal calls.

## State, Ownership, and Lifecycle
Public source/maps/results are immutable Sendable values with common Native/WASM/Embedded contracts. Local arrays own body frames, columns, resolved geometry directions and results for one synchronous invocation. No shared cache, unchecked conformance, pointer or accepted-state mutation. A conservative scalar reservation includes original immutable inputs, primal body/frame/joint snapshots, local jets, publication and fixed scratch: 2048*B+128*B*N+128*P+2048. B/N/P are caller-bounded. Supplier invocation counts remain in explicit caller-owned DerivativeSupplierWork; numerical operations remain in NumericalWork. Primal supplier arithmetic is unavailable and is identified as such, rather than invented from invocation count.

## Failure, Concurrency, and Constraints
Typed failures expose derivative-unavailable reason, invalid/mismatched/stale maps, nonfinite arithmetic, original mismatch/residual, cancellation and budget exhaustion. Work is O(B*N+B^2+P*(B+P)) plus identity bytes; memory is O(B*N+B+P). Counts use checked integer arithmetic. Bound every body/joint/parameter/column and bytes before traversal; poll caller/Task cancellation on each owned traversal and supplier boundary. Rank/singularity refusal from actual joint evaluation is preserved. Smooth selected derivatives never imply neighborhood validity across rank changes. All unsupported callable branches carry immediate incomplete markers and explicit refusal.

## Verification and Change Impact
Deferred behavioral evidence must perturb fixed-root and both anchor placements, non-unit raw axes, nonzero v/a and offset serial revolute/prismatic/screw chains; independently check pose/velocity/acceleration/J/bias derivatives and q/v-fixed semantics. Reject zero/boundary axis, mismatched raw chart/reference pose/provenance/revision, duplicate parameter IDs, topology/moving-anchor/unsupported charts, all budgets and cancellation. Later qualify actual public operations on Native/ordinary WASM/Embedded. No new builds/tests/probes/benchmarks/profiles or Git are run during implementation-first source work. Supplier conventions, admitted charts or mapping authority changes invalidate dependent evidence; root owns registration, integration and commits.

The subsequent selected Native qualification executed nine tests and eight public cases against the unchanged original2363 module/object closure. It independently checks literal SI/root-rotation values and central differences of original pose/motion/J/drift/bias at nonidentity placements, source/domain refusals, cumulative bounds and actual cancellation/supplier failures. Production23 remained unchanged. Exact fixture generation, emitted platform scope, retained fixture-only failures and execution evidence are owned by [GeometryParametersQualification](../../../../../Verification/GeometryParametersQualification/DESIGN.md#selected-native-execution). The subsequent complete registered Field1960 plus Geometry23 Native graph passed the same nine tests and eight public cases; exact canonical source/object/module bindings are owned by the [canonical Native registration evidence](../../../../../Verification/GeometryParametersQualification/DESIGN.md#canonical-native-registration). Ordinary/Embedded qualification remains pending. Neither Native proof qualifies the full OP-family or all target profiles.
