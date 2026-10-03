# PlanePatches

## Purpose and Scope
Parent [ContactPatches](../DESIGN.md), no children. Actual current Tet4/rigid-plane cuts and degree-two exact pressure integration for the admitted [PressureFields](../PressureFields/DESIGN.md) domain.

## Responsibilities and Boundaries
Own cut geometry, barycentric pressure, exact area/force/moment/consistent nodal loads and power evidence. Neither pressure equilibrium, friction, contact impulse, accepted rigid response, surface collision discovery nor time evolution is inferred. Consumer supplies physical pressure and identified rigid plane.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | CT-008 initial dispatch | Full hydroelastic family unqualified |
| [Fields](../PressureFields/DESIGN.md) | depends on | Pair, SI units, identities/work | Supplied field only |
| [Flexible](../../MechanicsFlexible/Mesh/DESIGN.md) | depends on | Reference inverse edges | Current det(F) checked here |
| [Tests](../../../Tests/MechanicsContactPatchesTests/DESIGN.md) | used by | Independent analytic integration/refinement | Root runs actual profiles |

## Architecture
```text
admitted representations -> positive current determinant -> six-edge cut -> convex 3/4-vertex polygon -> 1/2 triangles -> exact degree-two integration -> independent wrench/nodal/power residual
```

## Contracts and Invariants
Plane has common-frame point and unit normal, body/frame identity and revision, and actual prescribed spatial velocity about its declared point. For each Tet, current F is current edge matrix times verified reference inverse. det(F) must exceed caller minimumDeterminant. Nodes at the plane within caller distance tolerance are explicitly degenerate/unsupported; no arbitrary branch/face duplication. Nonintersecting valid cells produce physically empty geometry, not missing field success. Crossing edge interpolation gives actual position, Tet barycentric weights and affine nodal pressure. Vertices are ordered in the plane and triangles are oriented to the declared normal. For area A, affine vertex p and vector y, exact integral is A*((sum y)*(sum p)+sum(y*p))/12; scalar pressure integral is A*sum(p)/3. This degree-two identity integrates x*p, Ni*p and velocity*p exactly, not mean-pressure centroid approximation. Opposite wrench moments use the caller common origin; rigid power includes its translation and angular drift. Consistent compliant nodal forces preserve resultant/moment and interpolated virtual work. Original evidence compares nodal resultant/moment and nodal power against separate surface integrations. No potential/passivity claim is made for a frozen supplied pressure field; pressure contact can do prescribed work.

## Runtime Flows
Representation admission -> state/current-cell validation -> local cut/sort/integrate phases -> nodal resultant and power acceptance -> final cancellation -> immutable publication. No retry or supplier solver calls.

## State, Ownership, and Lifecycle
Caller owns exclusive PatchWorkspace with four reusable fixed cut records; no per-cell temporary arrays. Output triangles and nodal-force owner arrays allocate once after checked worst-case 2*cells triangles and nodes admission. Fixed records hold four barycentric scalars. Storage includes 64 workspace scalar-equivalent slots, 128 per triangle and 3 per nodal force; caller input backing remains immutable. Local non-inlined numerical phases prevent a monolithic debug stack lifetime.

## Failure, Concurrency, and Constraints
Shared work/cancellation authority belongs to PressureFields. Capacity is checked before output reserve. Current inversion, near-zero area, plane-vertex degeneracy, unsupported cut, residual rejection, nonfinite and resource/cancellation errors never publish partial success. Geometry/material/model/field revisions remain in output. No target-specific algorithm/backend substitution.

## Verification and Change Impact
Independent affine loaded triangle pressure/force/moment, consistent nodal virtual-work, rigid angular/translation power, orientation/reference transforms, actual Tet centroid refinement same-field integrals, absent contact and invalid/resource fixtures. Non-affine convergence, compliant-compliant interface/equilibrated field solve and general patch geometry remain unqualified. Changed integration/normal/origin semantics require IM23/27/39 consumers and root exact profiles to recheck.
