# Nonlinear structural stability continuation

## Purpose and Scope
Parent: [StructuralAnalysis](../DESIGN.md). No children. Own genuine multi-coordinate, conservative nonlinear equilibrium continuation and local constrained stiffness classification under ST-007, using actual calibrated Equilibrium models and compiled physical inertia. Root confirmed this AF29 boundary before implementation. Full IM28/ST-005..007 and210 requirements stay open.

## Responsibilities and Boundaries
The existing Buckling child owns the guided one-coordinate two-bar formula and Euler pencil. This child owns a general N-coordinate augmented original KKT algorithm, not another closed-form structural formula. Admitted source models are the actual existing conservative spring descriptors with independent affine time-independent mechanical constraints and at least two free coordinates. Fixed-base spatial scalar dynamic joint charts use actual compiled mass properties and fresh kinematics. No raw public mass/stiffness matrix, fabricated StructuralPencil/EquilibriumSolution/EquilibriumLinearization, hidden bar law beneath a spring descriptor, extra guide, automatic branch switch or inferred material hysteresis.

The Equations descriptor currently supports separable calibrated cubic springs and a one-coordinate pendulum. General nonlinear beam/bar continuum geometry and material history are concrete missing lower source contracts. This child cannot certify those domains, free/prescribed/planar/custom q-v charts, nonlinear or changing constraints, contact/nonsmooth forces, nonconservative follower loads or general elastoplastic buckling. A new unsupported source is explicitly refused; unchanged existing unsupported branches are not redirected.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [StructuralAnalysis](../DESIGN.md) | parent | IM28/ST005..007 dispatch | Root registers and integrates | Selected proof is not full-domain closure |
| [Equations](../../Equilibrium/Equations/DESIGN.md) | depends on | StaticForceModel/chart and required original force/tangent/parameter/energy evaluations | Calibrated source authority | Preserve the actual descriptor meaning and SI units |
| [Statics](../../Equilibrium/Statics/DESIGN.md) | depends on | Actual public equilibrium solve for initial accepted seed | Initial force/reaction evidence | Never fabricate its result through internal constructors |
| [Continuation](../../Equilibrium/Continuation/DESIGN.md) | coordinates with | Explicit branch/domain/state assumptions | Existing fixed-parameter continuation remains unchanged | It supplies no arc-length or limit-point algorithm |
| [Dynamics](../../../Physics/Dynamics/RigidEquations/DESIGN.md) | depends on | Fresh physical assembly and original inertial action | Actual mass source | Exact snapshot body order/ID/frame/inertia association required |
| [Constraints](../../../Physics/Constraints/CoordinateEquations/DESIGN.md) | depends on | Original admitted affine rows and layout | Mechanical linkage/boundary authority | Independent retained rows only, normalized coordinate units |
| [NonlinearSolve](../../../Mathematics/Nonlinear/NonlinearSolve/DESIGN.md) | depends on | Required generic original residual/Jacobian solve | Bounded numerical corrector | Success does not certify physical stability |
| [LinearAlgebra](../../../Mathematics/Numerics/LinearAlgebra/DESIGN.md) | depends on | Checked work, actual LU/Cholesky solves | Tangent and reduction algebra | Failed supplier work without ledger remains unavailable |
| [ComplexSpectrum](../../../Mathematics/Numerics/ComplexSpectrum/DESIGN.md) | depends on | Full eigensystem and original residual | General reduced stiffness spectrum | Independently verify physical projected tangent and mass norm |
| [Test owner](../../../../../Tests/MechanicsNonlinearStabilityTests/DESIGN.md) | used by | Independent coupled physical oracle | Native owner evidence | Root owns original profile/stack integration |

## Architecture
```text
immutable original spring model + affine linkage + compiled physical bodies
 -> chart/source/geometry/material/domain admission
 -> actual initial EquilibriumSolving result
 -> owned physically accepted point + oriented branch tangent
 -> normalized augmented original KKT + pseudo-arclength corrector
 -> original force/reaction/constraint/arc checks and derivative evidence
 -> fresh compiled q/zero-v snapshot -> actual inertia assembly/action
 -> derived constraint-null basis -> reduced original tangent + positive mass
 -> complete spectral classification + original projected equation checks
 -> immutable accepted state OR typed failure retaining prior state/work
```

## Contracts and Invariants
### Public boundary
`NonlinearStabilitySource` is an immutable Sendable final owner created from `StaticForceModel`, optional `StaticConstraints`, `CompiledMechanicalModel`, `EquilibriumBranch`, fixed time, explicit `EquilibriumLimits` and a caller `NumericalWork` ledger. It retains these actual values; constructor validates matching stamp/frame/scalar joint slots and source envelope before retaining data. The current `limits.identifierBytes` independently bounds model, parameter, branch, chart and compiled identity keys, source/asset/feature/schema/validator keys and retained dependency entity keys before equality or association. Metadata admission borrows UTF-8, charges every visited byte, polls cancellation and stops at the first excess byte; a larger earlier supplier envelope never overrides this source envelope. It admits no caller-supplied mass or tangent matrices. Sources with fewer than two free coordinates are outside this child's multi-coordinate contract. Affine rows are independent and layout-scaled; fully constrained or redundant boundaries fail explicitly.

`NonlinearStabilityContinuing` has required `start`, `advance` and `critical` operations. `ReferenceNonlinearStabilityContinuation` composes actual force, initial equilibrium, nonlinear, linear, inertia and spectrum protocol suppliers. Start consumes physical position/parameter seeds and an explicit oriented normalized q/parameter direction. Advance consumes a same-owner accepted `NonlinearStabilityState` and positive bounded arc step. Critical consumes a same-source adjacent accepted stable/unstable bracket and a bounded refinement policy. `NonlinearStabilityPolicy` is an immutable Sendable policy owner and explicitly owns supplier policies, force/constraint/arc/original tangent and inertial tolerances, parameter/time scales, positive-mass/zero-spectrum/load-projection thresholds, maximum accepted points, arc step/correction, critical iterations/width and cancellation. No correctness-affecting operational ceiling is hidden.

`NonlinearStabilityPoint` owns original physical q, load parameter, energy, gradient, generalized reactions and row multipliers, original force/constraint/arc residuals, full constrained stiffness eigenvalues/modes, original projected tangent residual, mass normalization and local classification. `NonlinearStabilityState` adds oriented augmented tangent, cumulative arc distance and accepted-step count. Its constructor is owned by this child. It is not an EquilibriumSolution and grants no authority to other owners. All sources, assumptions, branch and operating time remain inspectable.

### Original augmented equations
Let x_i=q_i/S_i, nu=p/P, E=model.energyScale and affine original row c_r(x)=c0_r+sum_i A_ri*x_i. Unknown z=[x,mu,nu]. Force equation is S_i*g_i(q,p)/E+sum_r A_ri*mu_r=0. Retained original constraints are c_r(x)=0. Corrector equation is t_q dot(x-x_predict)+t_p*(nu-nu_predict)=0, with predictor using the prior accepted tangent. Reaction components are not part of the geometric arc metric. The exact Jacobian uses original calibrated tangent, parameter derivative and affine constraint rows. A bordered tangent solve enforces derivative equilibrium/constraints and orientation; its physical q/parameter norm is one. Reported generalized reaction follows the existing Equilibrium convention R_i=-E/S_i*sum_r A_ri*mu_r; physical original balance is g_i-R_i=0. Every accepted point independently re-evaluates that original SI balance, every retained row, arc equation, conservative energy and directional tangent evidence. Solver diagnostics alone cannot publish a point.

### Local stability and critical evidence
Derive the free null basis from actual original affine rows; verify each original row annihilates each physical basis vector and that the basis is full-rank. Fresh actual compiled body inertias supply M(q). Compare original inertial actions to retained matrix actions. Derive H and projected mass from the calibrated original force tangent; no arbitrary matrix entry point. Mass must be positive definite within explicit normalized threshold. Publish the complete constrained generalized eigenpairs, real within stated spectral tolerance, with phi^T*M*phi=1 and original projected (H-lambda*M)phi residuals. Positive/neutral/negative local constrained stiffness are distinct from numerical failure; zero tolerance is stated. This is conservative local energetic stability, not global uniqueness, a dynamical damping certificate or a nonlinear continuum proof.

Critical refinement solves the original augmented equilibrium on bounded midpoint chord sections of an accepted bracket, preserving branch vicinity and original checks. It requires both a resolved zero-stiffness threshold and requested arc bracket width; premature or exhausted refinement fails. A simple zero mode with nonzero original mode/load derivative projection (normalized x-mode against S*g_p*P/E, dimensionless) is reported as a load-coupled limit-point candidate. A load-orthogonal zero mode is a bifurcation candidate, not a general theorem that a secondary branch exists. Independent actual secondary-branch continuation supplies the selected physical bifurcation evidence. Degenerate/multiple modes or ambiguous bordered tangents are explicit refusal; there is no silent automatic branch switch.

### Required-operation signatures
```swift
NonlinearStabilitySource.init(model: StaticForceModel, constraints: StaticConstraints?,
    compiled: CompiledMechanicalModel, branch: EquilibriumBranch, time: Double,
    limits: EquilibriumLimits, work: inout NumericalWork) throws(NonlinearStabilityFailure)

NonlinearStabilityContinuing.start(_ source: NonlinearStabilitySource,
    position: [Double], parameter: Double, initialDirection: [Double],
    policy: NonlinearStabilityPolicy, work: inout NumericalWork)
    throws(NonlinearStabilityFailure) -> NonlinearStabilityState
NonlinearStabilityContinuing.advance(_ source: NonlinearStabilitySource,
    state: NonlinearStabilityState, arcStep: Double,
    policy: NonlinearStabilityPolicy, work: inout NumericalWork)
    throws(NonlinearStabilityFailure) -> NonlinearStabilityState
NonlinearStabilityContinuing.critical(_ source: NonlinearStabilitySource,
    left: NonlinearStabilityState, right: NonlinearStabilityState,
    policy: NonlinearStabilityPolicy, work: inout NumericalWork)
    throws(NonlinearStabilityFailure) -> NonlinearStabilityCriticalPoint
```
Initial direction contains n+1 normalized q/parameter components; accepted augmented tangent contains n+r+1 q/reaction/parameter components. These required operations are declared in the owned source files.

## Runtime Flows
```text
start -> genuine initial solve -> original classification -> oriented tangent -> accepted state
advance -> predictor/corrector -> physical checks -> fresh mass/spectrum -> next tangent
        -> atomic immutable state publication
failure -> caller's accepted state remains unchanged; actual known work is returned
critical -> accepted bracket -> midpoint original correction/classification -> bounded bracket
         -> qualified local critical candidate or explicit unresolved/failure
```
No state mutation, hidden retry or branch adaptation is performed. At a true branch ambiguity continuation stops; caller can provide a distinct explicit secondary-branch seed through start.

## State, Ownership, and Lifecycle
One immutable source owner retains model/chart/branch/compiled bodies and source assumptions. State reuse requires both that exact source owner and the original immutable policy/metric owner (`===`), not a model stamp that can hide a changed same-revision spring/inertia law. An adjacent critical bracket also requires the exact previous-step identity. Opaque immutable step tokens prove adjacency without retaining a recursive state history. Fresh equivalent sources start independently; cross-owner state reuse is refused rather than inferred. Mutable arrays, work, LoadWork and phase workspace are operation-local. No cache, raw pointer, reflection, unchecked Sendable or target-conditional synchronization. Native/WASM/Embedded preserve identical stored types and Sendable/required-witness contracts. Caller synchronization owns any mutable cancellation callback state; callbacks execute outside locks.

Construction, corrector, fresh mass assembly, reduction/spectrum and publication use bounded separate noninline phases. Checked dimension products and explicit conservative reserves include live normalized equations, body/frame binding, input/output modes and retained accepted points. Nested suppliers receive only remaining budgets (and their own explicit policy caps); known success/failure ledgers are absorbed. Caller separately budgets aggregates retained across operations. Root authorized the immutable3fe26e1 owner copy and disk policy after contract confirmation.

## Failure, Concurrency, and Constraints
Typed `NonlinearStabilityFailure` carries cause, actual caller NumericalWork, failedSupplierWorkUnavailable and prior accepted state where present. Distinguish invalid/stale/source/unsupported, outside-domain/branch/correction/ambiguous tangent, bad derivative/mass/original residual, no critical bracket/unresolved critical point, cancellation/exhaustion and exact equilibrium/nonlinear/constraint/dynamics/linear/spectral causes. No false critical point after solver failure. A supplier lacking failed work stops the operation with unavailable-work evidence; no fabricated remaining budget or retry. Seed/prefix guards reject reset/changed ledgers and false finite candidates. Check caller cancellation at admission, bounded rows/iterations, after supplier work absorption and immediately before publication.

## Verification and Change Impact
The independent physical oracle uses three actual unit-mass prismatic siblings and the original spring descriptor a=[-1,-1,1], b=[1,1,0], load=[1,1,0], with actual affine q3-q1-q2=0. Let u=(q1+q2)/2,v=(q1-q2)/2. Independent potential U=u^2-v^2+u^4/2+3*u^2*v^2+v^4/2-2*p*u gives p=u+u^3+3*u*v^2 and v*(-1+3*u^2+v^2)=0; original reaction mu=-2*u at unit scales/E. Reduced original H=[[3*q1^2,1],[1,3*q2^2]] and actual mass [[2,1],[1,2]]. Symmetric branch v=0 has antisymmetric stiffness3*u^2-1 and bifurcation at u=1/sqrt(3),p=4/(3*sqrt(3)); actual explicitly seeded secondary branches v=+/-sqrt(1-3*u^2) have p=4*u-8*u^3 and a load reversal at u=1/sqrt(6),p=8/(3*sqrt(6)). The production algorithm consumes no such formulas.

Tests independently verify original force/reaction/energy/tangent/mass rows, both secondary branches, stability signs/zero mode, true passage through load reversal, midpoint critical refinement and step refinement. A separate higher-dimensional/nonzero-cubic-linkage model tests generic coordinate/constraint processing and derivative/mass actions without this oracle's symmetry. State/source refusal, changed law/inertia owners, nonlinear constraints/charts/material domains, forced solver failure versus actual instability, cancellation/capacity/iteration/storage/arithmetic, invalid/unknown supplier work and unchanged prior state are required. Existing Equilibrium/Structural/Numerics/ComplexSpectrum test owners remain unchanged. Exact Swift6.4.0 release Native owner setup1200seconds/four jobs and behavior240seconds precede root's original131072-byte WASI profile integration; no Native result is generalized to unexecuted profiles. Any change in original source, constraint, chart, tangent, inertia, branch metric or acceptance invalidates this child and its direct public consumers.

### Qualified owner evidence
Exact Swift6.4.0 release Native compile/link and the seventeen dedicated test declarations (twenty parameterized cases) passed in the immutable3fe26e1 owner archive. Symmetric bifurcation, both explicit secondary branches through genuine load reversal, critical bracket/step refinement and generic four-coordinate unequal-mass original equations passed without changing the selected tolerances. Eighty existing supplier/affected declarations also passed. The source-owned identifier envelope has an actual RED reproduction followed by GREEN, including exact visited-byte accounting; source/chart/policy identity, derivative/spectrum evidence, known/unknown supplier work, late cancellation and exhausted correction/refinement/resources were exercised. Logs and the owned-byte inventory are preserved under `.build/af29-independent-stability/`. This is Native evidence only; root owns original ordinary/Embedded WASM composition and the131072-byte stack. Full continuum/material/general structural requirements remain open.
