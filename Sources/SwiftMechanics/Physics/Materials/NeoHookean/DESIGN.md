# NeoHookean

## Purpose and Scope
Parent [Materials](../DESIGN.md); children none. One additive SwiftMechanics component for selected FX-005 and constitutive FX-006 behavior. Full requirement-family closure remains open.

## Responsibilities and Boundaries
Own the selected constitutive model, state association where applicable, exact original stress/strain, energy/work and derivative response. Caller owns calibration, placement and accepted mechanical/Runtime publication. No existing supplier or element implementation is changed.

## Related Designs
- Parent [Materials](../DESIGN.md): direct child composition and qualification boundary.
- Depends on [Constitutive](../Constitutive/DESIGN.md) public FiniteStrainKinematics/domain and [Core](../../../Mathematics/Core/DESIGN.md) checked Matrix3/Vector3 operations; immutable read-only suppliers, translated typed failure.
- Used by [public tests](../../../../../Tests/MechanicsThreeConstitutiveTests/DESIGN.md): independent physical and failure evidence.
- Primary model reference: [FEniCS hyperelasticity potential](https://docs.fenicsproject.org/dolfinx/v0.10.0.post3/cpp/demos/demo_hyperelasticity.html).

## Architecture
```text
immutable law + explicit sample / accepted value history
 -> required protocol witness -> exact checked constitutive calculation
 -> immutable response + physical energy/work/tangent + typed refusal
```

## Contracts and Invariants
Compressible isotropic neo-Hookean reference-volume potential psi=mu/2*(F:F-3)-mu*lnJ+lambda/2*(lnJ)^2 with mu>0, lambda>=0. Public FiniteStrainKinematics validates positive J and caller Green strain/J calibration. P=mu*F+(lambda*lnJ-mu)*F^-T; S=mu*I+(lambda*lnJ-mu)*C^-1; sigma=P*F^T/J. Required directional witness returns analytic dS/dP/dSigma for arbitrary finite H, and dPsi=P:H. Energy uses fixed-size public vector QR factors of F: sum[(Rii-1)^2+2*((Rii-1)-log1p(Rii-1))]+sum(offdiagR^2), with a bounded 24-term small-u log remainder. This is algebraically F:F-3-2lnJ while preserving positive tiny stretch/shear energy; no clipping or negative-energy fallback. Only proper positive QR diagonal/domain/invertibility paths are admitted. Model/objectivity/tangent checked on finite stretches/shear/rotation; incompressibility constraints, arbitrary calibration and flexible assembler/Runtime pairing remain separate owners.

Stress/moduli in Pa, viscosity Pa*s, strain dimensionless, time seconds, stored/input/dissipated energy per reference m^3. Neo-Hookean F and J are dimensionless; P/F pair is power conjugate. All intermediate/results used in publication must be finite; arithmetic/domain/provider association failure is MaterialError. Restored history must bind the identical law. Constitutive step failure preserves accepted input state.

## State, Ownership, and Lifecycle
Immutable Sendable laws/history/results; no shared mutable reference state or asynchronous resource. Closed-form scalar/fixed tensor workspace; only the bounded log remainder has local iteration, exactly 24 maximum terms. Native/WASM/Embedded retain the same stored types, Sendable and protocol requirements; no target-only lock removal or unsafe owner.

## Failure, Concurrency, and Constraints
Typed invalid parameter, incompatible history, calibrated domain, unrepresentable time/relaxation, checked Core arithmetic and nonfinite result. Scalar evolution has no Newton convergence shortcut or fallback. Neo-Hookean translates public Core errors explicitly. No dynamic array, unbounded workspace, hidden cache, I/O, callback mutation or unsafe pointer.

## Verification and Change Impact
Public NeoHookeanTests exercises independent analytic response, original energy/work/dissipation, history splitting/reversal or tangent/objectivity, and invalid/domain/arithmetic failures. Provider changes require only consuming component evidence to be rechecked; element/Runtime and whole-target interaction are not inferred. Only pinned Native compile/link/runtime is qualified by this task; portable profiles, minimum deployment and performance remain unverified.

### Selected Native qualification (2026-10-06)
Swift 6.4.0 release on arm64 macOS27.0.1. Canonical SwiftMechanics plus MechanicsThreeConstitutiveTests compiled/linked; final 16 public tests in three concurrent suites passed. Final build8.16s, test execution0.001s. Twenty exact source/test hashes match `.build/constitutive-evidence/source-freeze.json`. The public Burgers long-unloading case first failed with a zeroed finite tail, then passed after stable exponential endpoint evaluation. One source review and finding-only recheck completed; no unrelated implementation or broader test claim follows.

| Profile | Storage/isolation | Read/mutation/release | Qualification |
|---|---|---|---|
| Native | Immutable Sendable laws, history and responses; immutable injected Sendable supplier witness for SLS | Required public witnesses; only bounded local arithmetic/series variables mutate; caller retains history/provider | Selected compile/link/behavior passed |
| WASM | Identical stored types, conformance and witness contracts | Same value ownership; matching math ABI still requires qualification | Not built/executed in this task |
| Embedded | Identical stored types, conformance and witness contracts | Same value ownership and isolation; no lock/reference owner was removed | Not built/executed in this task |

Element/Runtime integration, minimum macOS13, performance, portable profiles and complete210 scope remain unqualified. See [test owner](../../../../../Tests/MechanicsThreeConstitutiveTests/DESIGN.md) for command and evidence boundaries.
