# ContactProducts

## Purpose and Scope
Parent [Derivatives](../DESIGN.md); children: none. Own OP-003 selected fixed-active directional products of qualified normal constitutive contact and threshold restitution prediction. Full OP-003 remains open for friction, coupled response/impulse, smoothing and generalized derivatives.

## Responsibilities and Boundaries
Fixed material, framed basis, accepted history and times are retained as original source. Directions vary separation and query-frame relative velocity, or incoming normal speed and energy, with one dimensionless perturbation. No geometry, basis, material, history, mass, impulse, event-time or coupled solve derivative is inferred. Unsupported laws fail explicitly. Existing producers and derivative children are read-only.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Parent](../DESIGN.md) | parent | requirement ownership | Selected OP-003 provider | No whole-domain completion |
| [Response](../../../Physics/ContactLaws/Response/DESIGN.md) | depends on | ContactLawEvaluating | Actual continuous primal | Original source/history checked |
| [Impact](../../../Physics/ContactLaws/Impact/DESIGN.md) | depends on | ContactImpactPredicting | Restitution primal | No impulse claim |
| [Inputs](../../../Physics/ContactLaws/Inputs/DESIGN.md) | depends on | ContactWork/ContactBudget | Supplier accounting | Work is irreversible |
| [Tests](../../../../../Tests/MechanicsContactDerivativeTests/DESIGN.md) | used by | independent behavioral proof | Owned Native qualification | Profile composition root-owned |

## Architecture
```text
source + finite direction + caller neighborhood/policy/work
 -> bounded metadata / branch admission
 -> injected primal (seeded remaining allowance) -> builtin original primal
 -> full original output/source comparison -> analytic fixed-branch product
 -> immutable source-bound result + validity rectangle / typed failure
```

## Contracts and Invariants
`ContactDifferentiating.contact(input:pair:accepted:direction:policy:work:)` returns ContactResponseTangent. `impact(pair:approachSpeed:incomingNormalEnergy:direction:policy:work:)` returns ContactImpactTangent. Both are nongeneric requirements. ExactContactDifferentiator injects ContactLawEvaluating and ContactImpactPredicting without fallback; builtin producers independently validate supplied primal before publication.

Contact admits linear/Hertz/Hunt-Crossley normal laws with no friction/cohesion/resistance and no material sites. Open, compressive and clipped branches are explicit. Caller positive separationRadius/normalSpeedRadius define a closed SI rectangle centered at source. Every point must remain strictly inside the selected branch and material envelope. Separation zero, force-clamp zero and neighborhood crossings are nonsmooth refusal. Energy remains elastic even on clipped unloading. Fn=max(Fe-d*vn,0) or HC=max(Fe*(1-alpha*vn),0); U integral of Fe, L=(Fe-Fn)*vn, P=Fn*vn. Products use these original equations, not published inactive-side derivative conventions. Basis is fixed; derivative force is n*dFn. Returned validity records exact branch and admitted coordinate bounds. No claim outside rectangle.

Impact admits positive speed/energy and separateImpact only. Speed rectangle must remain on one strict side of threshold and above zero. Products: dRebound=e*dSpeed, dRetained=e²*dEnergy, dLoss=(1-e²)*dEnergy; dEffectiveRestitution=0 within fixed branch. Incoming energy is an independent normal-mode scalar, not an inferred mass. Threshold equality is refused even when configured restitution is zero.

Policy owns identifier-byte cap, SI radii, absolute/relative primal tolerance, primal acceptance policy and cancellation callback. Limits are caller choices. ContactDerivativeWork owns cumulative contact-unit operations/storage; it absorbs verified known supplier prefixes even after Task cancellation because the frozen ContactWork.consume cannot do so. No guessed iteration or global storage limit. Work precharges fixed arithmetic/storage before arrays/math/publication, metadata is bounded and charged per byte. Returned source includes original input/pair/history; history equality checks all revisions, sequence, time, bristle and dissipation.

## Runtime Flows
Admission -> supplier boundary quantum -> seeded local remaining budget -> opaque callback -> validate unchanged budget and seed on success AND failure -> absorb executed known local prefix -> cancellation -> independent builtin -> original comparison -> product. Failure is terminal, with no unknown-work retry. Builtin validation is also budgeted and may fail after supplier work is preserved.

## State, Ownership, and Lifecycle
Immutable Sendable service/source/result; call-local exclusive inout ContactDerivativeWork. No shared state, caches, platform branches or unsafe storage. Rich publication follows supplier calls; fixed workspace and bounded borrowed identifiers. Caller alone publishes trial history. Derivative never mutates accepted history.

## Failure, Concurrency, and Constraints
Typed ContactDerivativeError distinguishes invalid direction/policy, unsupported domain, nonsmooth neighborhood, original mismatch, stale original law error, resource/cancel and invalid supplier ledger with unavailable-work flag. Reserve boundary before callback. A local seeded ledger uses one snapshot of caller remaining operations, bounded records/storage. Total executed admitted operations cannot exceed caller maximum. Absorption preserves known success/failure prefixes; reset or budget replacement reports unavailable work and preserves caller's irreversible boundary. Task and policy cancellation are checked before/after callbacks. Same Sendable/state contract on Native/WASM/Embedded.

## Verification and Change Impact
[Owned tests](../../../../../Tests/MechanicsContactDerivativeTests/DESIGN.md) prove independent normal force/U/L/P products, rotated basis, clamp/open/domain boundaries, impact energy partition and threshold, actual primal refinements, supplier wrong-source output/reset/failure/cancel/capacity, history replay and legacy producers. Owner isolated Native baseline1bf65c3 proof uses exact Swift6.4.0, bounded setup1200/test240; root owns canonical integration and original three profiles. No unexecuted profile claim.

### AF27 isolated Native evidence
The frozen owned implementation was overlaid onto committed baseline `1bf65c3` in `.build/af27-independent-contact-derivatives`. The private manifest registers only MechanicsContactDerivativeTests and exact existing MechanicsContactLawsTests, MechanicsContactResponseTests, MechanicsHybridTests and MechanicsDerivativesTests; all production/executable targets, dependencies and compiler flags remain unchanged.

Exact Swift6.4.0 setup `swift build --build-tests --build-path .build/native -j 4` used a1200second timeout. First setup exposed one owned test Task catch inference error, corrected with an explicit typed do; the incremental setup exited zero. Separate240second `swift test --skip-build --build-path .build/native -j 4` exited zero: new14 declarations/25 parameter cases in3suites, existing67 declarations in13suites; total81declarations/16suites. The actual logs are private copy `.build/af27-contact-native-setup.log`, `-setup-2.log`, and `-tests.log`. Only Native selected behavior is qualified here; root owns canonical cumulative and original-profile qualification. No full OP-003 completion claim.
