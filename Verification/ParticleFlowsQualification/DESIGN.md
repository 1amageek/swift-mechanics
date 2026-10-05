# ParticleFlowsQualification

## Purpose and Scope
Parent: [package](../../DESIGN.md). Children: none. Own independent selected public behavioral witnesses for [ParticleFlows](../../Sources/SwiftMechanics/Physics/Fluids/ParticleFlows/DESIGN.md). Preparation is not qualification. Root owns target registration and execution slots.

## Responsibilities and Boundaries
Exercise actual Wendland/Tait/Morris prepare/evaluate/trial requirements through `any ParticleFlowOperating`. Independently calculate original SI density, EOS, force, heat, boundary work and midpoint endpoint. Selected homogeneous compressive bulk and prescribed constant-velocity ghost only; no continuum convergence, free-surface, dynamic FSI, Runtime publication or thermal EOS claim.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [ParticleFlows](../../Sources/SwiftMechanics/Physics/Fluids/ParticleFlows/DESIGN.md) | used by | Original public state/diagnostics and typed failures | Original18 must match admitted fresh producer before link |
| [Numerics](../../Sources/SwiftMechanics/Mathematics/Numerics/DESIGN.md) | depends on | NumericalWork cumulative budget | Work is never reset inside a call |
| [Core](../../Sources/SwiftMechanics/Mathematics/Core/DESIGN.md) | depends on | Finite Vector3 and NumericalTolerance | Independent oracle uses public geometry, not SPH helpers |

## Architecture
```text
caller SI calibration -> independent polynomial kernel / binomial EOS / oriented pair sums
                    |                                              |
                    v                                              v
actual ParticleFlowOperating -> sealed state -> evaluation/trial -> fixed comparisons
                    |                                              |
                    +---- typed refusal / budget prefix / cancel ---+
```

## Contracts and Invariants
| Shared case | Independent falsifiable witness |
|---|---|
| kernelNormalization | Original radial integral, support and finite-difference derivative at two smoothing lengths |
| densityAndEOS | Self density, unequal independent density summation, pressure and positive binomial energy near rho0 |
| midpointMomentumEnergy | Original force and midpoint endpoint, uniform gravity ballistic motion and full energy |
| viscosityAndHeat | Nonnegative original Morris loss, finite-fluid heat and actual pressure/viscous endpoint |
| prescribedGhostWork | Original drifting quadrature, opposite reaction, mechanical/reservoir power and trial work |
| admissionAndTime | Tensile/density/Mach/separation/duplicate/identity/capability/time-step typed refusals, unchanged input |
| exactWorkBounds | Independent one-particle charge/iteration/storage counts, exact capacity and one-less refusals |
| NativeCancellation (test only) | Actual pre-cancelled Task invoking production requirement; numerical.cancelled and zero consumed prefix |

Fixed oracle comparison: absolute 2e-9 plus relative 2e-10 of expected magnitude; near-reference energy uses absolute1e-24 plus relative2e-8. Kernel central difference step1e-6*h uses relative2e-7. Radial Simpson2048 panels accepts absolute2e-10. Production force/power/density-rate/momentum residual tolerances are absolute1e-9 and relative1e-11 with explicit SI scales. Production energy tolerance is absolute1e-6 J plus relative1e-10 with scale1000 J; this allows the declared finite-order midpoint defect and is independently checked against the fixed computed endpoint energy. No oracle or tolerance changes after first execution without a concrete fixture error and recorded causal correction.

## Runtime Flows
Seven synchronous cases are shared unchanged by Swift Testing and public executable. Native adds an awaited eighth cancellation test. Oracle never calls kernel/eos/force private helper or uses returned production density as its input. Tests use operation-local inputs and NumericalWork. All failure calls preserve admitted state and consumed work prefix.

## State, Ownership, and Lifecycle
Production inputs/output arrays are immutable values; NumericalWork is call-exclusive. Cancellation test uses structured Task cancellation, no shared mutable test state, static cache or target-dependent synchronization. All synchronous case bodies remain portable ready. No fixture changes production capability/Sendable/storage contracts.

## Failure, Concurrency, and Constraints
Typed assertion and unexpected-success errors reject fake success; original typed failure is inspected exactly. Reference fixtures have at most two finite particles and one ghost. Current AF36 runner compiles the committed source graph and directly imports its one dylib: the consumer has support3/test1/public1 only, no SwiftMechanics source target or object copies. Pinned release6.4.0/MacOS27 SDK: production/support/public actual targetmacOS13, Swift Testing target/runner actualmacOS14. No fixture Mutex15 or suite availability annotation is required. Producer WMO threads4/enable-testing and all actual driver final jobs4 are recorded. Root granted one cold lease: cumulative additional8GiB/global floor4GiB,2s sampling/max5s, producer1200s/consumer900s/tests120s/public120s. Historical128MiB narrow evidence uses a separate old baseline.

## Verification and Change Impact
Prepare source/fixture SHA freeze, original18/depot comparison and direct immutable object/module binding. Record actual commands, source/object/library/binary before/after, first failure and resource abort. Concrete owned production counterexample requires DESIGN-first causal change and fresh matching producer; old module mixing is forbidden. Parent/shared Package/PROGRESS/Git remain root-owned. Preparation alone has no compile/link/runtime success claim; actual executed scope is recorded below.

### First Native finding: independent fixture arithmetic
Initial link/build passed; first eight-test run passed seven physical/failure/cancellation cases and rejected only the independent exact-work assertion. Diagnostic-only context then showed653 operations,6 iterations,397 storage. The fixture had correctly listed original operation groups308+64+32+12+48+120+40, but incorrectly summed them as724 instead of624. Independent integer addition of those original primitive/phase charges gives624 before metadata29, hence653. Three original evaluations give3*624; two updates80, replay12, balance96 and publication1 give2061 before metadata. The sole correction changes those two fixture arithmetic totals, not production charges or bounds, physical oracles, original call shape, budget semantics, residual tolerances or seven previously passed cases. Both initial and diagnostic-only RED attempts were recorded before the subsequent capacity cleanup; their `.build` artifacts are no longer available. One affected test is the finding-limited retest, followed by the original seven shared public cases.

### Historical selected Native evidence (artifacts subsequently lost)
The former deleted final receipt SHA18049ee5a3ad78f6d89c4957cf363b1dabdeeb782826b9f64fd87aa9f440166e binds unchanged production18, final fixture5, all original2363 object/three module metadata paths and SHA, library, public artifact and original failure/continuation receipts. Production aggregate263391d5e52b7739d249be15d03786fcfe977a3064c516df624f127507edfcc4 and fixture aggregated28cc1a2dc45c9a19f385cdfbf0505c3d75aa61bfe4d257696c15533bfd0bd35 use sorted repository-relative path+NUL+original bytes+NUL. Historical unrelated AF31 supplier divergence remains explicitly outside this selected physical qualification. Source/module/object identity was validated before and after each successful phase; no production Swift changed and no objects were duplicated.

One original2363 dylib was linked in0.431s, fixture-only initial build in7.076s. Actual emitted driver lines retain effectivejobs4, exact release6.4.0/MacOS27 SDK/macOS13. The first eight-test run passed seven unchanged cases, including actual Task cancellation; only fixture arithmetic failed. A diagnostic-context-only attempt preserved that RED and fixed no oracle. The documented integer-addition correction rebuilt only fixture outputs in0.924s; the affected work-bound test passed in0.482s. The planned final seven synchronous public cases passed once in0.349s against the same dylib8e3b4756da173d2acd17e8f9d779e16d31567d329a69041ae72e109701cf293f. Final public SHA d955cd04b0e52412b469adfd3ec97cd9f3bdde3a768028949fb501cd51c91560. No final all-eight suite rerun is claimed. Native-backend deprecation warnings remain in logs.

The same immutable model/state and call-exclusive work were exercised; nativeCancellation uses real structured Task cancellation and production cancellation checks, no fixture callback substituting for that check. One-less operation/iteration/storage failure and cumulative evaluate/trial work passed against independently summed primitive charges. Fixed physical oracles, tolerances and original capability refusals were unchanged.

The original allocation baseline3,002,368B was retained across all attempts. Maximum sampled additional94,081,024B stayed below112MiB early stop and128MiB cap; minimum sampled free890,998,784B exceeded784MiB early stop/768MiB floor. Sampling is bounded2s/max5s and transient allocator peaks are not claimed. Commands retain120s link/public,900s build and60s test watchdogs. NativeB was released immediately after final public completion. Portable, global Runtime acceptance, full current-root registered composition, continuum convergence and dynamic fluid/rigid feedback remain unqualified. No extra compute is required by this documentation update.

### Fresh AF36 Native evidence after artifact loss
Earlier snapshots/objects/receipts/runners were lost; historical prose is not current compiled authority. Unchanged production18 aggregate263391d5e52b7739d249be15d03786fcfe977a3064c516df624f127507edfcc4 and finalfixture5 aggregated28cc1a2dc45c9a19f385cdfbf0505c3d75aa61bfe4d257696c15533bfd0bd35 retain original equations/tolerances/oracles and624+29 prepare/2061+29 trial ledger.

Git archive of committed5d4e16e4b38b556a957a5059c1fcc999f43c8d83 plus its actual Package exclusions admits2014 Swift, including13 registered HydraulicElements. The predecessor Terrain receipt proves selected2001 and omitted those13. After the initial source-count assertion stopped before compilation, root chose committed HEAD authority: actual2014+unchanged Particle18 gives fresh2032. No live uncommitted lower source is included. Source freeze c51c9a2748d699d110bae65014a101fafe50dc245b044d581f95e65e506d27dc records that distinction.

Fresh producer compile+dylib link passed32.051s. Inspector initially rejected the link driver for lacking frontend-only WMO flags; the causal parser correction distinguishes compile from link without producer regeneration. Initial consumer generated runner inherited a bare paired-I and failed an unexpected-input diagnostic. Joined `-I<same exact module path>` fixes private spelling only; original failure logs and manifest are preserved. Corrected consumer build passed2.161s. All original8 tests, including actual structured Task cancellation, passed1.220s; unchanged public7 passed0.289s through the same actual dylib. No production or fixture Swift changed.

[Fresh Native receipt](../../.build/af36-particle-native/fresh-native-joined-include-receipt.json) SHA ffda73383b221d8498221f9830022318788159b30b5e06c9dd986c3a43978b38 binds all2032 source/object pairs, module metadata3 and actual library. All protected bytes matched after tests/public. [Actual consumer drivers](../../.build/af36-particle-native/consumer-driver-proof.json) record finaljobs4 and production/support/public13 versus actual Swift Testing14; neither is generalized to Mutex15. Cumulative sampled additional910,864,384B <8GiB and minimum free183,477,915,648B >4GiB; unsampled peaks are not claimed. Compiler lease released after execution; producer remains read-only for root's Terrain thin reconfirmation.

This qualifies selected discrete Particle physics/failures/budgets/cancellation on fresh Native2032. Portable execution, continuum convergence, dynamic FSI and global Runtime publication remain open. Root owns shared manifest/index/Git; fixed-predecessor registration candidate does not establish a later union HEAD composition.
