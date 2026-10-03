# Bounded Green-strain J2 plasticity

## Purpose and Scope
Parent: [MechanicsMaterials](../DESIGN.md). Owns a bounded additive Green-strain J2 material with linear isotropic hardening, trial/accepted value history and consistent algorithmic tangents for FX-005 and the constitutive part of FX-006. Children: none.

## Responsibilities and Boundaries
Material-frame additive E=Ee+Ep, S=Ktr(E)I+2μ dev(E-Ep); Ep is deviatoric. Free energy ψ=K(trE)²/2+μ dev(E-Ep):dev(E-Ep)+Hα²/2. Yield q=sqrt(3s:s/2)<=σy+Hα. This is a bounded small material/plastic-strain approximation permitting arbitrary superposed spatial rigid rotations. It is not multiplicative finite plasticity, finite plastic rotation evolution or universally calibrated metal behavior. Caller sets total-strain, accumulated-plastic-strain and J bounds. Element/corotational/ANCF choices remain IM19.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../DESIGN.md) | parent | Value state/qualified support | Composition | Accepted state assignment is caller authority |
| [Constitutive](../Constitutive/DESIGN.md) | depends on | Green strain, stress push-forward | Objectivity | Material history does not rotate under spatial Q |
| [Elasticity](../Elasticity/DESIGN.md) | depends on | K,μ elastic operator | Recoverable stress/energy | Bounds apply to actual strain |

## Architecture
```text
(material,acceptedHistory,E) -> elastic predictor
q-yield > 0 -> radial return -> candidate history/stress/energy/dissipation
residual and calibration acceptance -> immutable PlasticTrial
caller accepts -> next evaluation receives trial.history
caller rejects -> original accepted history remains unchanged
```

## Contracts and Invariants
Finite σy>0 Pa, H>=0 Pa, maximum α>0, finite tolerances abs>0 Pa and rel>=0 are required. Closed-form Δγ=max(0,(qtrial-σy-Hα)/(3μ+H)), n=3strial/(2qtrial), Ep'=Ep+Δγn and α'=α+Δγ. Plastic history retains the exact immutable material and rejects use by a different law/calibration. Yield residual is checked against caller abs+rel*stressScale; numerical residual above policy throws nonConvergence without a candidate. ΔD=S':ΔEp-H(α'²-α²)/2=σyΔγ+HΔγ²/2>=0 is the backward-Euler discrete plastic dissipation. PlasticTrial.history is a value, not an automatically accepted commit.

Algorithmic tangent holds accepted history fixed and differentiates the active branch: δstrial=2μ devδE, δq=3strial:δstrial/(2q), δγ=δq/(3μ+H), a=1-3μΔγ/q, δs'=aδstrial+(-3μδγ/q+3μΔγδq/q²)strial. Volumetric direction is KtrδE I. At exact initial yield the elastic branch is selected; there is no two-sided derivative across the branch transition. Finite tangent composes δE=sym(FᵀδF) and stress geometric terms. Resource cost O(1); no iterative solver, unbounded iteration or size-dependent allocation.

## State, Ownership, and Lifecycle
Material/history/trial values are immutable Sendable with internal history constructors. Initial state belongs to material; a trial candidate can be independently accepted, rejected or forked. History stores deviatoric reference Ep and α; operation-local mutation never escapes. No shared state, platform branch, async resource or pointer is present.

## Failure, Concurrency, and Constraints
Invalid parameters/tolerance, incompatible history, exceeded α/E/J, arithmetic overflow and residual nonconvergence are typed failures. Accepted input state is never modified. Nonconvergence means failure of the closed-form return's numerical acceptance, not an iterative algorithm claim. No scalar fallback/model substitution is permitted.

## Verification and Change Impact
[PlasticityTests](../../../Tests/MechanicsMaterialsTests/PlasticityTests.swift) freezes K=1000,μ=400,σy=20,H=100 Pa, total norm<=0.2, α<=0.1,J>=0.5. Manufactured traceless loading has analytic return q'=σy+Hα'; shear and forward/reverse cycles demonstrate recovery/residual strain, positive discrete dissipation and independent history forks. Tangents are central-checked away from yield using 1e-6 step, 1e-3 Pa+1e-6 relative tolerance. Tests cover rigid rotation, bounded-history rejection, exact-law mismatch, overflow and deliberately strict residual nonconvergence. No element behavior or whole-platform runtime is established. Changing return/history/tangent semantics rechecks future evolution and IM19 consumers.
