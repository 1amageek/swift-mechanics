# Materials behavioral verification

## Purpose and Scope
Test owner for [Constitutive](../../Sources/MechanicsMaterials/Constitutive/DESIGN.md), [Elasticity](../../Sources/MechanicsMaterials/Elasticity/DESIGN.md) and [Plasticity](../../Sources/MechanicsMaterials/Plasticity/DESIGN.md). Parent: [MechanicsMaterials](../../Sources/MechanicsMaterials/DESIGN.md). Children: none. Verifies constitutive kernels, not flexible elements.

## Responsibilities and Boundaries
Independent analytic SI fixtures establish uniaxial/shear stress and energy, Green-strain response, radial return, discrete dissipation, unloading recovery, directional tangent and rigid-rotation objectivity. Failure fixtures exercise calibration, arithmetic, history compatibility and residual acceptance. Platform composition belongs to root verification.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Module](../../Sources/MechanicsMaterials/DESIGN.md) | parent | Qualified material support | Test scope | No element/ANCF claim |
| [Elasticity](../../Sources/MechanicsMaterials/Elasticity/DESIGN.md) | depends on | Stress/energy/tangents | Analytic fixture | Tensor shear |
| [Plasticity](../../Sources/MechanicsMaterials/Plasticity/DESIGN.md) | depends on | Trial history and active branch tangent | Return/cycle fixture | Accepted history held fixed |

## Architecture
```text
Frozen SI fixtures -> production protocol requirements -> analytic/directional/invariant assertions
Invalid fixtures -> production rejection -> unchanged original value history
```

## Contracts and Invariants
Fixtures use K=1000,μ=400,β=800,σy=20,H=100 Pa, prescribed strain and caller-calibrated domain. Analytic stress/energy tolerance is 1e-9 SI absolute plus 1e-10 relative; kinematic tolerance is 1e-12. Tangent central step 1e-6 and tolerance 1e-3 Pa plus 1e-6 relative are fixed independently of candidate output. Test suites have one-minute time limits and command execution is bounded by the root timeout wrapper. Tests share no mutable resource and can run concurrently.

## Verification and Change Impact
Run `python3 Scripts/run_with_timeout.py 180 swift test --build-path .build/material-kernels --filter 'ElasticityTests|PlasticityTests'`. Native behavioral results cover the actual tested inputs; fixed-profile WASM/Embedded compile/link/runtime is root-owned. Changes to the model equations/domain/return/tangents must reconsider the independent expected values and input envelope before running candidate tests.
