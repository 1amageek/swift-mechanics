# ChannelDiscretization

## Purpose and Scope
Initial admitted implementation domain; behavioral/profile qualification pending. Parent [Fluids](../DESIGN.md); no children. Own fixed-geometry cell-centered finite-volume parallel-plate incompressible Newtonian flow. Full EX-005 ownership remains beyond this initial domain.

## Responsibilities and Boundaries
Own homogeneous streamwise/spanwise geometry, SI density/viscosity, constant acceleration, cell topology, wall/source samples, immutable field state and hydrostatic face pressure. x is streamwise, y is transverse, z is spanwise in the supplied fixed world frame. Uniform x/z fields have exactly zero convective term and zero divergence. This is a real reduction of incompressible momentum, not a general 3D solver. No compressibility, free surface, turbulence, particulate interaction, coupled body force, or moving geometry is qualified.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [Core](../../MechanicsCore/DESIGN.md) | depends on | EntityID frame identity | Fixed oriented frame; no inferred transform |
| [Model](../../MechanicsModel/DESIGN.md) | depends on | SourceProvenance | Identity and revision retained |
| [Compiler](../../MechanicsCompiler/DESIGN.md) | depends on | ModelStamp | Runtime carrier binding, not fluid DOFs |
| [Numerics](../../MechanicsNumerics/DESIGN.md) | depends on | NumericalWork | Charged storage/arithmetic; no unreported solver work |
| [Evolution](../ViscousEvolution/DESIGN.md) | used by | physical cell data | Uniform FV topology authority |
| [Continuation](../Continuation/DESIGN.md) | used by | complete immutable state | Byte binding preserves all physical parameters |

## Architecture
```text
bounded identities + physical SI channel -> admitted fixed cell layout
wall/source sample -> hydrostatic face recurrence -> immutable fluid state
```

## Contracts and Invariants
Channel height H [m], wall area A [m²], density rho [kg/m³], dynamic viscosity mu [Pa s] are positive finite; h=H/n and derived cell mass/conductance must remain positive finite. gx/gy [m/s²], axial pressure gradient [Pa/m], wall speeds and cell u [m/s], time [s], gauge pressure [Pa]. Gauge pressure may be signed; no EOS/cavitation claim. Caller supplies maxCells/maxMetadataBytes before identity traversal or array allocation, maximum speed/absolute pressure/source magnitude/step duration. Boundary law identity/revision is independent of per-step samples. Source and wall samples are piecewise constant during each accepted interval; state retains its last sample. All cells share the same material. Pressure recurrence p[j+1]=p[j]+rho*gy*h has independently checked per-cell original gradient balance; the lower-face gauge is authority. The lower pressure face must exactly equal its retained gauge sample. Field array counts and finite/domain limits are revalidated at every service entry. Arrays are immutable owned output; call-local arrays are exclusively mutable. No hidden caches or target conditionals.

## Failure, Concurrency, and Constraints
Typed invalidInput/domain/capacity/staleBinding/cancelled/nonfinite/originalResidual failures; caller budgets precede traversal/allocation. No unsupported regime is silently mapped to this channel. Cancellation hooks are immutable Sendable and polled at bounded cell rows and before publication. Native/WASM/Embedded have identical immutable state and local workspace owners.

## Verification and Change Impact
[Tests](../../../Tests/MechanicsFluidsTests/DESIGN.md) own hydrostatic original force balance, invalid/capacity/nonfinite/stale field checks. Changes to cell geometry/units/binding invalidate Evolution/Continuation acceptance and their tests. Qualification requires actual tests and exact-profile execution owned by root.
