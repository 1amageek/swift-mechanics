# StandardLinearSolid

## Purpose and Scope
Parent [Materials](../DESIGN.md); children none. One additive SwiftMechanics component for selected FX-005 and constitutive FX-006 behavior. Full requirement-family closure remains open.

## Responsibilities and Boundaries
Own the selected constitutive model, state association where applicable, exact original stress/strain, energy/work and derivative response. Caller owns calibration, placement and accepted mechanical/Runtime publication. No existing supplier or element implementation is changed.

## Related Designs
- Parent [Materials](../DESIGN.md): direct child composition and qualification boundary.
- Depends on [MaxwellRelaxation](../MaxwellRelaxation/DESIGN.md) MaxwellLaw/State/Evolving public requirements; immutable read-only suppliers, translated typed failure.
- Used by [public tests](../../../../../Tests/MechanicsThreeConstitutiveTests/DESIGN.md): independent physical and failure evidence.
- Primary model reference: [COMSOL linear viscoelasticity](https://doc.comsol.com/6.4/doc/com.comsol.help.sme/sme_ug_theory.06.029.html).

## Architecture
```text
immutable law + explicit sample / accepted value history
 -> required protocol witness -> exact checked constitutive calculation
 -> immutable response + physical energy/work/tangent + typed refusal
```

## Contracts and Invariants
Scalar infinitesimal standard linear solid: equilibrium spring E0>0 in parallel with a Maxwell branch E1>0, eta>0. Held strain rate r over positive dt updates total strain and public Maxwell branch history. sigma=E0*epsilon+sBranch, U=E0*epsilon^2/2+sBranch^2/(2*E1), D=integral(sBranch^2/eta)dt. Own original mean total stress, work=meanStress*r*dt, storage change and work-storage-dissipation residual. Immutable state binds exact law/time/strain; caller maximumStrain bounds the monotone held-rate interval, Maxwell branch owns its rate/stress envelope. A required MaxwellEvolving witness is injected, default ExactMaxwellEvolution; provider must uphold its documented physical contract, and returned law/time association is checked. No scalar history is silently migrated and no element/Runtime publication is added.

Stress/moduli in Pa, viscosity Pa*s, strain dimensionless, time seconds, stored/input/dissipated energy per reference m^3. Neo-Hookean F and J are dimensionless; P/F pair is power conjugate. All intermediate/results used in publication must be finite; arithmetic/domain/provider association failure is MaterialError. Restored history must bind the identical law. Constitutive step failure preserves accepted input state.

## State, Ownership, and Lifecycle
Immutable Sendable laws/history/results. The evaluator retains an immutable Sendable MaxwellEvolving witness; any injected provider owns its internals and must honor the supplier contract. The default supplier is an immutable value. No mutable reference state or asynchronous resource is owned by this component. Closed-form scalar/fixed tensor workspace; only the bounded log remainder has local iteration, exactly 24 maximum terms. Native/WASM/Embedded retain the same stored types, Sendable and protocol requirements; no target-only lock removal or unsafe owner.

## Failure, Concurrency, and Constraints
Typed invalid parameter, incompatible history, calibrated domain, unrepresentable time/relaxation, checked Core arithmetic and nonfinite result. Scalar evolution has no Newton convergence shortcut or fallback. Neo-Hookean translates public Core errors explicitly. No dynamic array, unbounded workspace, hidden cache, I/O, callback mutation or unsafe pointer.

## Verification and Change Impact
Public StandardLinearSolidTests exercises independent analytic response, original energy/work/dissipation, history splitting/reversal or tangent/objectivity, and invalid/domain/arithmetic failures. Provider changes require only consuming component evidence to be rechecked; element/Runtime and whole-target interaction are not inferred. Only pinned Native compile/link/runtime is qualified by this task; portable profiles, minimum deployment and performance remain unverified.

### Selected Native qualification (2026-10-06)
Swift 6.4.0 release on arm64 macOS27.0.1. Canonical SwiftMechanics plus MechanicsThreeConstitutiveTests compiled/linked; final 16 public tests in three concurrent suites passed. Final build8.16s, test execution0.001s. Twenty exact source/test hashes match `.build/constitutive-evidence/source-freeze.json`. The public Burgers long-unloading case first failed with a zeroed finite tail, then passed after stable exponential endpoint evaluation. One source review and finding-only recheck completed; no unrelated implementation or broader test claim follows.

| Profile | Storage/isolation | Read/mutation/release | Qualification |
|---|---|---|---|
| Native | Immutable Sendable laws, history and responses; immutable injected Sendable supplier witness for SLS | Required public witnesses; only bounded local arithmetic/series variables mutate; caller retains history/provider | Selected compile/link/behavior passed |
| WASM | Identical stored types, conformance and witness contracts | Same value ownership; matching math ABI still requires qualification | Not built/executed in this task |
| Embedded | Identical stored types, conformance and witness contracts | Same value ownership and isolation; no lock/reference owner was removed | Not built/executed in this task |

Element/Runtime integration, minimum macOS13, performance, portable profiles and complete210 scope remain unqualified. See [test owner](../../../../../Tests/MechanicsThreeConstitutiveTests/DESIGN.md) for command and evidence boundaries.
