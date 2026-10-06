# Vehicles

## Purpose and Scope
Parent: [Physics](../DESIGN.md). Own selected vehicle/terrain physical laws and assemblies within IM42 and SPEC EX-001..003. Current children: [TireLaws](TireLaws/DESIGN.md) and [TerrainLaws](TerrainLaws/DESIGN.md). Complete assemblies and calibrated-terrain/track domains remain requirements.

## Responsibilities and Boundaries
Own vehicle-specific constitutive assumptions, slip/road conventions and calibration metadata. Existing mechanics owners retain rigid dynamics, contact, transmissions, actuation and accepted-state authority. A tire law is not a complete vehicle simulation.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Physics](../DESIGN.md) | parent | Physical responsibility boundaries | Composition owner | Full210 remains open |
| [Core](../../Mathematics/Core/DESIGN.md) | depends on | Qualified physical geometry/units | Frames and physical values | Admitted domain only |
| [Loads](../Loads/DESIGN.md) | depends on | Qualified force/power representation | Vehicle external force meaning | Preserve work and sign |
| [ContactLaws](../ContactLaws/DESIGN.md) | coordinates with | Qualified physical contact meaning | Tire/terrain domain distinctions | No implicit generic law substitution |
| [TireLaws](TireLaws/DESIGN.md) | child | Selected calibrated tire/road law | Independent implementation owner | Native8/public7 on full1841 registered composition; portable open |
| [TerrainLaws](TerrainLaws/DESIGN.md) | child | Calibrated fixed-footprint sinkage/shear trial and accepted histories | Explicit terrain constitutive owner | Selected Native7/public7 at fresh2001; portable and moving footprints remain open |

## Architecture
```text
immutable vehicle/road/calibration data + current physical port sample
    -> admitted selected constitutive law
    -> original force/torque/power diagnostics or typed failure
    -> mechanics consumer (separate authority)
```

## Contracts and Invariants
Every child states physical equations, coefficient/calibration limits, slip definition and frame/temporal interpretation. No hidden empirical model substitution or full-assembly claim. Qualified suppliers retain their own capabilities. Registration is feature-specific: TireLaws and selected TerrainLaws have Native behavioral evidence; target-specific portable proofs remain separate.

## State, Ownership, and Lifecycle
Immutable Sendable inputs/results with exclusive operation workspaces. Future stateful tire/terrain histories require explicit trial/accepted/checkpoint contracts. Shared mutable state retains common Mutex/actor and Sendable contracts across targets.

## Failure, Concurrency, and Constraints
Invalid physical inputs, missing calibration, outside-domain conditions, stale source identity, work/storage limits and cancellation fail explicitly. Discontinuous/slip/zero-speed policies are attributable; no silent defaults or fabricated terrain.

## Verification and Change Impact
Law-specific independent curve/energy/frame/failure evidence belongs to the child and is linked there. Vehicle assemblies, coupling and actual target profiles have separate proofs and cannot be inferred from law source availability. Changes to force/calibration contracts invalidate directly dependent assemblies.


## Selected WheeledAssemblies Native composition

Child [WheeledAssemblies](WheeledAssemblies/DESIGN.md) owns selected six-body wheeled assemblies. Its original Native8/public7 behavioral evidence is qualified against fresh immutable2387, with original source/physical/work acceptance and typed failures preserved. The child and qualification owner retain exact evidence and remaining portable/domain obligations.
