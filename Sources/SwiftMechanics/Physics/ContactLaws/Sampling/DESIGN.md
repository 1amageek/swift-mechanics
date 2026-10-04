# Current accepted-state contact sampling

## Purpose and Scope
Parent: [ContactLaws](../DESIGN.md). Children: none. This component owns instantaneous sampling of the existing compliant constitutive laws at an issued, immutable accepted history. AF29 prerequisite .0 has selected independent Native behavioral evidence; canonical and original profile qualification remain parent-owned and pending. It does not qualify contact evolution or the full contact requirement family.

## Responsibilities and Boundaries
The required service `ContactCurrentEvaluating.sample(input:pair:accepted:policy:work:)` consumes `ContactCurrentInput` with identity, basis, separation, relative linear/angular velocity and `timeSeconds`, with no time step. `ContactCurrentResponse` associates the exact accepted history with current force, couple, potentials, rate powers, branch derivatives and original power evidence. It never issues a history, changes bristles, releases energy or performs a return map. Response owns the shared constitutive equations; Sampling owns accepted-state admission and instantaneous rate evidence.

Geometry, tangent-axis advection, integration, impacts and accepted/rejected runtime transactions are consumer authorities. A supplied basis expresses the accepted bristles in advected material axes under the Inputs contract. History does not contain a previous basis or friction regime; this service cannot infer their transport or a current sliding mode. Its elastic traction is admitted against the static ellipse, including arbitrary finite slip at virgin zero bristles. This is neither maximum-dissipation Coulomb friction nor a sliding evolution law.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [ContactLaws](../DESIGN.md) | parent | Constitutive responsibility and dispatch | Root owns composition and qualification | Full contact scope remains open |
| [Response](../Response/DESIGN.md) | depends on | Pure normal/cohesion/resistance and framed scalar kernels; issued history | Same equations as trial evaluation | Shared extraction must preserve trial arithmetic and failure order |
| [Inputs](../Inputs/DESIGN.md) | depends on | Identity/basis, SI quantities, work and acceptance policy | Admission and metadata accounting | Caller advects material axes; no automatic transport |
| [MaterialPairs](../MaterialPairs/DESIGN.md) | depends on | Resolved pair and loss policy | Exact pair association | No re-pairing or loss substitution |
| [Current tests](../../../../../Tests/MechanicsContactCurrentTests/DESIGN.md) | used by | Analytic sample and refusal oracles | Local behavioral proof | Existing response regression is also required |

## Architecture
```text
current input + issued accepted history + resolved pair
 -> bounded metadata scan -> exact identity/pair/time association
 -> shared normal/cohesion kernels + frozen elastic bristles
 -> static-ellipse admission -> shared resistance/framed mapping
 -> current branch derivatives + independent power balances
 -> final cancellation check -> immutable sample (same history)
```

## Contracts and Invariants
All dimensional scalars use SI: separation/bristles m, velocity m/s, angular velocity rad/s, force N, couple N m, potentials J and rate powers W. Relative velocities and force/couple on B share the supplied query frame and sign convention. No impulse is produced. Input identity must equal the accepted full identity, pair must equal the accepted resolved pair, and current time must equal accepted time exactly. Material sites, geometry/model/layout/frame revisions are retained through that association. Virgin history comes from the existing required `initialHistory` operation, not a constructed approximation.

With accepted bristles z and tangential stiffness kt, Ft_i=-kt*z_i and Ut=kt*(z1²+z2²)/2. Disabled friction requires zero bristles. If Fn=0, any nonzero accepted bristle is refused; no epsilon, release or fabricated zero history is used. For Fn>0, the original traction must satisfy the static anisotropic ellipse within caller cone tolerance. A load decrease that breaks this test is refused instead of modifying state. Cohesion does not enlarge the friction/resistance load. Normal, cohesive and resistance equations and their original branch conventions are owned by Response.

Force and couple use the shared framed map. The sample publishes mechanical pair power P=F·v+tau·omega and its independent local-axis residual. It additionally publishes the elastic rate expression dU/dt=-Fe*vn-Fc*vn-Ft·vt and checks P+dU/dt+Dn+Dr=0 with caller dimensional power tolerance. Fe is the shared normal elastic force; Dn=(Fe-Fn)*vn and Dr=-tau·omega are continuous rates. The tangential term is the reversible material-axis rate expression under zdot=vt, not an advancement of accepted z or a plastic/discrete dissipation assertion. No previously accumulated discrete tangent loss is re-counted as current power. At cohesive branch boundaries this is the selected branch rate convention, not a smooth two-sided evolution guarantee.

The derivative record publishes frozen-basis/history partials: Fn with respect to penetration and vn; Fc with respect to separation within its selected branch; Ft with respect to accepted z; rolling tangent 2x2 and spin angular derivatives; and framed couple derivative with respect to compressive Fn. Normal/cohesive smoothness flags identify their breakpoints; derivatives at those points retain the selected one-sided/inactive convention rather than claiming differentiability. Resistance uses the same regularized law with positive omegaReg. The record is not a derivative of the admission gate, return map, cone projection, geometry, basis transport or integration. In particular the elastic algebraic bristle slope does not grant a nonzero-bristle variation at Fn=0. Angular derivatives use normalized transverse/regularization ratios, preserving small positive regularization contributions without subtracting nearly equal squared ratios. Original normal and resistance kernel evaluation is shared; derivative-only arithmetic is performed only for Sampling and can fail if it is not finite.

## Runtime Flows
Association checks precede constitutive work. Domain and static-ellipse failures stop the operation before output publication. No retry or alternate law executes. Global/local power and rate balance are independently checked before a final cancellation checkpoint. Repeated sampling of identical inputs and accepted history is deterministic. Current sampling at a changed velocity does not require or imply a trial at a manufactured time step.

## State, Ownership, and Lifecycle
All public input, result, derivative, error and service values are Sendable. Accepted history remains caller owned and is returned only as its unchanged immutable association. `ContactWork` is exclusive inout operation-local accounting; no arrays, heap workspaces, cache, hidden mutable state or unsafe views are introduced. Native, ordinary WASM and Embedded use the same storage and Sendable contracts. Output owns its finite vectors and scalar records.

## Failure, Concurrency, and Constraints
`ContactCurrentError` retains underlying `ContactLawError` and distinguishes unloaded/disabled nonzero bristles and inadmissible accepted traction. Existing finite normal envelopes, overflow, invalid frame/time, stale history/pair, arithmetic, resource and cancellation failures remain typed. Caller selected `ContactBudget` is consumed before constitutive work: a conservative 4096 operation-unit envelope, 512 scalar accounting slots plus both identities' existing material-site storage, and one result record. These are declared conservative accounting units, not allocator bytes, instruction counts or an iteration limit. The path is scalar and loop-free except metadata scans. Existing borrowed UTF8 accounting charges each byte before identity/pair comparisons and checks cancellation during traversal; source provenance is not compared. Checked final publication prevents publishing a sample after cancellation. There is no failed opaque supplier: the shared kernels use the same exclusive work boundary and no nested solve.

## Verification and Change Impact
The dedicated test owner will prove virgin slip, issued loaded bristles without mutation, normal linear/Hertz/HC values and derivatives, independent normal/cohesive/elastic rate identities, resistance angular derivatives, rotation covariance, exact history association, static-ellipse and unloaded refusals, stale pair/time/revisions, nonfinite/domain, long-key resource limits, scalar/record limits and cancellation. Finite differences are derivative oracles only. Existing ContactLaws behavioral tests must run against the shared kernel extraction and preserve original output, history, accounting and refusal behavior. The dedicated test owner records selected independent Native evidence; the parent records canonical and original profile qualification after execution. Consumers of current samples must independently qualify their dynamics and accepted-state lifecycle.
