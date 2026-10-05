# Nonlinear transmission kinematics

## Purpose and Scope
Parent: [Transmissions](../DESIGN.md). Selected TR-011/AC-007 service owns six independent ideal scalar maps: offset slider-crank, single Cardan joint, variable-lead screw, periodic harmonic cam, cycloidal rise and quintic 3-4-5 rise. Children: none. All implement NonlinearTransmissionEvaluating in the existing SwiftMechanics module.

## Responsibilities and Boundaries
Owns original closure/profile geometry, fixed assembly/phase conventions, exact first/second derivatives, conjugate force mapping, local inverse rate/effort diagnostics and an instantaneous adapter to the published affine actuator API. Supplied parameters define ideal geometry; no CAD shape, bearing reactions, surface contact, friction, stiffness, mass, solver row, compiler lowering or accepted Runtime evolution is inferred. Existing legacy unsupported transmission modes remain unchanged. Cam lift functions specify follower coordinate, not a manufactured contact surface or roller offset.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Transmissions](../DESIGN.md) | parent | Phase, fidelity and power ownership | Selected nonlinear maps | Full TR family remains open |
| [Loads PassiveLaws](../../Loads/PassiveLaws/DESIGN.md) | depends on | ScalarCoordinateKind SI convention | Input rad, output rad or m | Effort is conjugate to coordinate |
| [Actuation Ports](../../Actuation/Ports/DESIGN.md) | depends on | AffineTransmission and ActuationWork public constructors | One-coordinate instantaneous derivative adapter | Caller supplies model/frame authority; zero gradient rejected by original supplier |
| [Tests](../../../../../Tests/MechanicsSixTransmissionTests/DESIGN.md) | used by | Six public conformers and adapter | Independent geometric/profile/power oracles | Native only |

## Architecture
```text
six immutable SI geometries + bounded input q
    -> exact nonlinear sample {q, f(q), f'(q), f''(q), coordinate kinds}
    -> v_out=f' v_in; a_out=f' a_in+f'' v_in^2
    -> conjugate effort pullback / independent power residual
    -> caller-identified instantaneous AffineTransmission -> existing actuation supplier
```

## Contracts and Invariants
Input/output positions and rates are unwrapped, with radians numerically dimensionless; translation uses m, m/s and N, rotation uses rad, rad/s and Nm/rad. A sample has one admitted input coordinate and immutable derivative values. The adapter is valid only at that sampled coordinate; it neither integrates position nor supplies a Hessian to the affine owner. Users must re-evaluate nonlinear geometry when the input changes.

| Model | Original map and domain | Failure/branch |
|---|---|---|
| SliderCrankTransmission | theta=q-inputPhase; y=offset-r*sin(theta); f=outputOffset+r*cos(theta)+sign*sqrt(l^2-y^2) | Explicit positive/negative rod-projection assembly; abs(y)>l impossible, abs(y)=l singular. r,l>0; caller input range may include refused closures |
| CardanTransmission | theta=q-inputPhase; f=outputPhase+theta+atan2((c-1)sin(theta)cos(theta),cos(theta)^2+c*sin(theta)^2), c=cos(beta)>0 | abs(beta)<pi/2, no wrapping or turn inference; fixed yoke phase makes tan(output-outputPhase)=c*tan(theta) |
| VariableLeadScrewTransmission | theta=q-inputPhase; f=outputOffset+theta*(leadAtPhase+leadSlope*theta/2) | Signed lead m/rad must be strictly same sign at both caller-domain endpoints; crossing/zero lead rejected |
| HarmonicCamTransmission | theta=q-inputPhase; f=outputOffset+lift*sin(theta/2)^2 | Periodic bilateral ideal lift; lift>0; no dwell section or contact inference |
| CycloidalCamTransmission | u=(q-startAngle)/riseAngle; f=outputOffset+lift*(u-sin(2*pi*u)/(2*pi)), 0<=u<=1 | Exactly one rise interval, no implicit dwell/fall continuation; endpoint first/second derivatives zero |
| QuinticCamTransmission | u=(q-startAngle)/riseAngle; f=outputOffset+lift*u^3*(10-15u+6u^2), 0<=u<=1 | Exactly one 3-4-5 rise interval, no implicit dwell/fall continuation; endpoint first/second derivatives zero |

Geometry/model context is supported by [MathWorks slider-crank](https://www.mathworks.com/help/simscape/ref/slidercrank.html), [MathWorks universal joint](https://www.mathworks.com/help/sdl/ref/universaljoint.html), and [COMSOL cam follower profiles](https://www.comsol.com/blogs/how-to-model-a-cam-follower-mechanism/). Equations and the explicit Cardan phase convention above are the contract authority; implementations are independently derived.

Motion includes the f''*v^2 convective acceleration. Effort pullback is Q_in=f'*Q_out. Original independent powers Q_in*v_in and Q_out*(f'*v_in) are reported separately, with their raw rounding residual; no loss is invented. Local reverse rate and effort require an explicit caller threshold in output/input coordinate units; abs(f')<=threshold rejects inversion even for zero requested quantities. A zero derivative remains a valid forward sample and pullback, exposing dead center/dwell without division. A threshold is never guessed from a fixture.

Fixed-sized scalar arithmetic has O(1) time/storage and no dynamic allocation in geometry/motion/power operations. The only array allocation is the one-entry affine output boundary after ActuationWork reserves its one scalar. Stable sinusoidal remainder and factored polynomial retain tiny lift/derivatives; arithmetic overflow rejects explicitly instead of clamping or changing assembly.

## State, Ownership, and Lifecycle
Public stored properties are immutable Equatable/Sendable values. No retained mutable workspace, caches, pointers, actor, Mutex or unchecked isolation is introduced. Operation-local series variables do not escape; all six models can be evaluated concurrently. Caller owns the lower ActuationWork exclusively via inout, including cancellation and failed work.

## Failure, Concurrency, and Constraints
NonlinearTransmissionError distinguishes invalid parameters/input, bounded input refusal, impossible/singular closure, local inverse singularity and nonfinite result. Fallible affine construction preserves original ActuationError, model/frame identity, resource/cancellation failure and zero-gradient refusal. Failed evaluation does not alter a model or earlier samples. Platform math imports are real scalar-lib differences; Native evidence does not qualify WASM/Embedded.

## Verification and Change Impact
Six separate named suites use independent closure/profile values, analytic dead-center/quarter-turn fixtures, central first/second derivative checks at two refinement steps, nonlinear acceleration chain rule and signed power balance. Each tests the actual existing ActuationTransmitting requirement using its sample adapter, correct model/frame/rate metadata and explicit failure paths. Common tests cover zero derivative local inverse refusal and lower work/cancel limits. Source review, frozen hashes, canonical Native test product, commit and merge preserve untouched lower suppliers/main pending changes. Changed common sample/math invalidates all six suites; a model-local formula change invalidates only its own suite. Runtime/constraint enforcement, contact geometry, minimum-platform/portable/performance/full210 remain separate.

Selected Native evidence: the canonical MechanicsSixTransmissionTests product built with Swift 6.4.0 release on macOS 27.0.1 arm64 and passed 49 behavioral tests in seven concurrent suites. Twenty-two source/test Swift files are frozen with SHA-256 receipts; 23 original actuator/coordinate/identity/numerical supplier files match main without modification. This receipt does not qualify contact, Runtime constraint enforcement, minimum-platform, WASM, Embedded or performance.
