# Particle Flows

## Purpose and Scope

Own EX-005 three-dimensional weakly compressible SPH for a homogeneous Newtonian liquid in a compressive bulk domain. Parent: [Fluids](../DESIGN.md). No children. Historical selected Native execution covered the public discrete equations and refusals described by the [independent qualification owner](../../../../../Verification/ParticleFlowsQualification/DESIGN.md). Its `.build` receipts and producer artifacts were subsequently lost during capacity recovery; current source/object/link authority requires a fresh matching producer and execution, currently pending. Portable execution, continuum accuracy, global integration and Runtime publication remain outside that evidence.

## Responsibilities and Boundaries

Own actual Wendland C2 summation density, calibrated integer-exponent Tait pressure and barotropic energy, antisymmetric pair pressure, positive Morris viscosity, prescribed ghost quadrature, explicit midpoint trials and original equation/balance gates. Caller supplies physical masses, ghost volumes/densities/kinematics, material calibration, gravity, inertial frame identity/revision, source, scales, tolerances and numerical budget. Ghost quadrature weights are not finite fluid mass. No CAD geometry, wall mass, soil law, free-surface stabilization, thermal pressure coupling, or dynamic rigid-body FSI authority is inferred.

## Related Designs

| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Fluids](../DESIGN.md) | parent | EX-005 ownership | Adds a separate particle discretization | Other source-only fluid components are not dependencies |
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | Vector3, NumericalTolerance | Checked finite arithmetic and dimensional residual gates | Frame is caller-certified inertial Cartesian SI |
| [Model](../../../Modeling/Model/DESIGN.md) | depends on | EntityID, SourceProvenance | Original frame and source retention | Scoped UInt64 particle IDs do not invent a Model entity kind |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | NumericalWork, NumericalBudget | Checked storage/arithmetic/iteration caps | Budget is never reset during a trial |
| [Runtime](../../../Execution/Runtime/DESIGN.md) | coordinates with | accepted/trial authority | Immutable SPH candidate is not a Runtime accepted state | No contributor codec or commit adapter is claimed |
| [Integration](../../../Execution/Integration/DESIGN.md) | coordinates with | original endpoint admission principle | Each stage and endpoint are reevaluated | No unqualified consumer or supplier implementation is used |

## Architecture

```text
caller model + particles + policy
    -> ReferenceWeaklyCompressibleSPH : ParticleFlowOperating
       -> WendlandC2Kernel -> summation density -> Tait EOS
       -> unordered fluid pairs / prescribed ghost pairs
       -> independent oriented original-equation reevaluation
       -> midpoint stage -> endpoint reevaluation -> balance gates
    -> immutable ParticleFlowState / ParticleFlowTrial + original diagnostics
```

## Contracts and Invariants

For q=r/h<2, W=21/(16*pi*h^3)*(1-q/2)^4*(2*q+1); otherwise W=0. Its original gradient is -5*alpha/h^2*(1-q/2)^3*(x_i-x_j), including zero at coincidence. Every particle includes m_i W(0). Density includes all original fluid and ghost supports; no neighbor omission or empty-field success occurs.

Tait B=rho0*c0^2/gamma, p=B*((rho/rho0)^gamma-1), c=c0*sqrt((rho/rho0)^(gamma-1)). Caller gamma is an exactly Double-representable integer >=2; fractional gamma is outside this declared domain. Specific barotropic energy, zero at rho0, is B/rho0*[((rho/rho0)^(gamma-1)-1)/(gamma-1)+(rho0/rho-1)], whose original derivative is p/rho^2. Implementation evaluates the algebraically identical positive remainder [(1+d)^gamma-1-gamma*d]/[(gamma-1)*(1+d)] using logarithmic exponent composition to avoid cancellation near rho0. Separate accumulated viscous heat is diagnostic and does not feed this barotropic EOS.

Fluid pair pressure F_i=-m_i*m_j*(p_i/rho_i^2+p_j/rho_j^2)*grad_i W; F_j=-F_i. Density derivative is sum_j m_j*(v_i-v_j).grad_i W. Morris damping coefficient C=-2*mu*m_i*m_j/(rho_i*rho_j)*(r_ij.grad_i W)/(r_ij^2+eta*h^2)>=0. F_visc_i=-C*(v_i-v_j), original loss C*|v_i-v_j|^2>=0, split equally as heat between finite fluid particles. Caller eta>0 is an explicit numerical regularization parameter. Units are kg/m^3, Pa, m/s, N, J/kg, W respectively.

Ghost q_g=rho_g*volume_g replaces m_j only as a quadrature weight. Its pressure is calibrated by the same EOS; its position is caller reference position plus constant prescribed velocity times elapsed time. Each original fluid/ghost force has opposite retained boundary reaction. All ghost-pair viscous loss becomes finite-fluid heat. Boundary mechanical power is F_fluid.v_g; fixed-density pressure-reservoir power is -m_i*q_g*p_g/rho_g^2*(v_i-v_g).grad W. Their sum equals the original fluid kinetic+barotropic+heat power after gravity removal. Ghost stored energy or inertia is not invented.

Admission is compressive no-tension bulk: rho>=rho0, caller relative density band <=0.1 and Mach limit <=0.3, with positive minimum particle separation. Pressure is never clipped. These limits select a low-Mach computational domain; they are not a proof of continuum accuracy or universal SPH stability. Free-surface/tensile stabilization and dynamic rigid feedback have immediate incomplete markers and typed refusal.

## Runtime Flows

Preparation admits identity, particles and supplied ghost samples, evaluates actual density/EOS/forces, and independently reevaluates each oriented particle equation. A positive caller dt generates an explicit midpoint stage and endpoint; all three evaluations must pass actual acoustic CFL, viscous, acceleration, Mach and density-change limits. Viscous admission checks both h^2/nu and the actual assembled damping row sums. Trials retain diagnostics from all three stages. An evaluation with nil dt explicitly carries no time-step admission. No hidden retry or dt reduction occurs. Original endpoint momentum change is gated against midpoint gravity and boundary impulse. Original total energy (kinetic+barotropic+viscous heat+gravity potential) change is gated against midpoint prescribed mechanical plus reservoir work. Nonzero finite-order integration defects are accepted only within caller dimensional tolerances. State revision increments only in the returned immutable candidate. Failure leaves the input snapshot unchanged.

## State, Ownership, and Lifecycle

Public models, states, trials, samples, policies and diagnostics are immutable Sendable values on every target. Arrays use ordinary immutable COW ownership at output boundaries; no view escapes. Local evaluation/stage arrays and NumericalWork are operation-exclusive. No shared mutable storage, unsafe memory, actor bypass, or target-dependent concurrency contract exists. State retains the complete model/source/frame and original particle order/IDs; reactions retain ghost IDs. Caller owns publication/lifetime; this component has no accepted-state mutation authority.

## Failure, Concurrency, and Constraints

The declared reference neighbor path is O(N^2+N*G), with no grid/backend fallback. Each candidate pair, oriented reevaluation, EOS power multiplication, identity comparison, stage update and balance operation charges bounded arithmetic upper bounds before execution and checks cancellation at row/pair boundaries. Storage is reserved before temporary materialization using checked 128+metadataBytes+240*N+96*G scalar-slot upper bounds covering input/model retention, all simultaneous three-stage evaluation/state arrays, ghost positions/reactions, and local ledgers; no pair-sized cache is retained. Material arithmetic, density squares and viscosity denominators must be representable finite positive values. Integer overflow, exhausted budget, cancellation, nonfinite arithmetic, duplicate IDs, stale identity, unsupported domain, insufficient separation, CFL/Mach/density refusal and failed original residual are typed failures. No iteration count implies success.

## Verification and Change Impact

Primary equation sources: [PySPH original Wendland kernel](https://github.com/pypr/pysph/blob/main/pysph/base/kernels.py), [LAMMPS Tait/Morris documentation](https://docs.lammps.org/pair_sph_taitwater_morris.html), and [LAMMPS original SPH pair implementation](https://github.com/lammps/lammps/blob/develop/src/SPH/pair_sph_taitwater_morris.cpp). Equations were read, not delegated to an unqualified dependency. Reservoir-work identity and the barotropic integral above are derived from these declared discrete equations.

Source review must trace kernel derivative, self-density, unordered/oriented pair equivalence, positive loss, ghost reaction and reservoir work, midpoint storage/work and endpoint residuals. The independent [ParticleFlows qualification owner](../../../../../Verification/ParticleFlowsQualification/DESIGN.md) prepares selected kernel, compressive EOS, uniform velocity, viscous pair, moving prescribed boundary work, finite/CFL/tensile refusal, cancellation/resource exhaustion and unchanged failed-prefix witnesses. Continuum hydrostatics/refinement and Runtime coupling are outside that selected evidence; existing [Runtime tests](../../../../../Tests/MechanicsRuntimeTests/DESIGN.md) establish Runtime authority only. Historical selected2363 artifacts were lost and cannot establish present compiled authority. Fresh committed predecessor5d4e16e admits2014 actual HEAD sources including13 registered HydraulicElements; unchanged Particle18 gives2032. Fresh source/object/module/dylib-bound execution passed all original8 Native tests and unchanged public7 with fixed oracles/tolerances/624+29 ledger. Protected bytes matched after runtime. The qualification owner records actual commands, tool-boundary RED continuations and fresh receipt SHA ffda73383b221d8498221f9830022318788159b30b5e06c9dd986c3a43978b38. This establishes the declared selected discrete Native domain; portable behavior, continuum convergence, dynamic fluid/rigid feedback and Runtime publication remain outside it. Kernel/EOS/pair changes require reevaluating all original balance gates and direct parent assumptions; Runtime/FSI adapters require separate owning qualification.
