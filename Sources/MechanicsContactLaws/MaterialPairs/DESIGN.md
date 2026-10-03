# Explicit material pairing
## Purpose and Scope
Parent [module](../DESIGN.md). Owns material parameters, explicit model/loss selection, symmetric combination and ordered override provenance. Children: none.
## Responsibilities and Boundaries
Normal compliance only: linear, Hertz and Hunt-Crossley. Rigid complementarity and optimization-based models have no callable declaration here and remain deferred. Material parameters are point-contact parameters, not density/inertia/display geometry.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Inputs](../Inputs/DESIGN.md) | depends on | Model references/work/errors | Identity/bounds | Ordered material references preserved |
| [Response](../Response/DESIGN.md) | used by | resolved pair | Physical law | Exact pair equality binds history |
| [Impact](../Impact/DESIGN.md) | used by | loss policy | Restitution | No double normal-loss counting |
## Architecture
```text
validated two materials + explicit normal selection/loss -> symmetric combination
ordered exact-reference override -> replacement resolved parameters + recorded override revision
```
## Contracts and Invariants
E>0 Pa, -1<nu<0.5; k>0 N/m, c>=0 N s/m, alpha>=0 s/m. Symmetric series rule k=1/(1/kA+1/kB), c=0 if either c=0 else harmonic series; E*=1/((1-nuA²)/EA+(1-nuB²)/EB), alpha=(alphaA+alphaB)/2. Friction requires both explicit none or both elastic-Coulomb; mixed selection fails. Positive muDynamic<=muStatic per axis, kt>0 N/m, transition speed>0 m/s. Pair uses per-axis minima, series kt, mean transition speed. Rolling/spinning coefficients>=0 dimensionless, angular regularization>0 rad/s; pair uses minima/mean speed and caller radius>0 m. Cohesion uses explicit none if either material selects none, otherwise minimum tensile force/range. Override contains exact ordered material references and full resolved parameters; wrong order fails, changed revision fails stale. Overrides and symmetric rule are recorded in pair output. A present full override is authoritative for all resolved parameters; default selection and resistanceRadius arguments apply only to the symmetric branch. Override normal coefficients are caller-calibrated, distinct from the symmetric branch material-derived Hertz coefficient.
Hertz K=(4/3)E*sqrt(R), R>0 m; Hunt-Crossley uses same K plus alpha. Caller supplies finite maximum penetration and normal-speed envelopes; Hertz/HC require maximumPenetration<R and delta<=maximumPenetration. Small-strain/Hertz/calibration adequacy is a caller assumption, not derived from radius alone. Linear has its independently calibrated penetration envelope. Separate impact restitution e in [0,1] and threshold>=0 cannot coexist with selected c>0 or alpha>0; damping-only explicitly selects continuous loss. Pair equality includes every model coefficient/envelope, material references, loss and override provenance.
## Failure, Concurrency, and Constraints
Invalid parameters, mixed friction laws, overflow, stale/order-mismatched override, incompatible loss selection and resource exhaustion fail; no defaults choose a physical model. Immutable Sendable pair/material/override values; constant workspace.
## Verification and Change Impact
[PairingTests](../../../Tests/MechanicsContactLawsTests/PairingTests.swift) independently calculate series/modulus/min results, swap order, exercise overrides/revisions and restitution-damping conflict. Pair edits invalidate Response history and Impact evidence.
