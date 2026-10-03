# Independent framed constitutive inputs
## Purpose and Scope
Parent [module](../DESIGN.md). Owns SI inputs, contact/body/geometry/frame/layout identity and caller budgets. Children: none.
## Responsibilities and Boundaries
No collision type, geometry calculation, impulse or accepted-time lifecycle. Caller supplies separation s (m; positive open), v=vB-vA (m/s), omega=omegaB-omegaA (rad/s), dt>0 (s). Normal points A to B. Result force/couple act on B and their negatives on A at the consumer's contact application locations.
## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../../MechanicsCore/DESIGN.md) | depends on | finite Vector3/UnitQuaternion | SI/right-handed math | Propagate Core failures |
| [Model](../../MechanicsModel/DESIGN.md) | depends on | ModelReference/EntityID | Identity authority | Caller owns geometry revisions |
| [Response](../Response/DESIGN.md) | used by | input and work | Constitutive evaluation | No geometry inference |
## Architecture
```text
Model references + contact-to-query quaternion -> tangent x/y, normal z in query frame
separation + relative linear/angular velocity + dt -> bounded constitutive input
```
## Contracts and Invariants
ContactIdentity contains nonempty contact key, ordered distinct body references, common frame reference, independent geometry revisions and tangent-layout revision. ContactBasis uses a Core unit quaternion; local x/y define material anisotropy axes and local z the normal. Its frame reference must exactly match input identity. Tangent axes are caller-advected material directions; changing their physical definition requires a layout revision. Scalar input validation rejects nonfinite s, negative/nonfinite start time and nonpositive/nonfinite dt. Input has no independently supplied tangential displacement: the only displacement authority is dt times projected relative velocity, preventing contradictory displacement/velocity inputs. Response acceptance uses caller dimensional energy/power absolute tolerances, a relative term and positive reference energy/power, plus an independent dimensionless cone tolerance. Selected backend is reference Float64 CPU, with no fallback.
## State, Ownership, and Lifecycle
All records immutable Sendable. ContactWork is a caller-owned value passed inout; no reference/global storage. History components follow the advected tangent axes, preserving elastic energy under rigid rotation; this is not an automatic rolling/slip transport algorithm.
## Failure, Concurrency, and Constraints
Budget has nonnegative operation-quanta/scalar-slot/output-record limits. Each operation charges metadata UTF8 scans (two quanta per byte, using borrowed UTF8 views) before identity comparisons; input construction owns its own metadata validation. No unconstrained successful equality scan is hidden behind the fixed scalar charge. Each operation also preflights fixed conservative scalar bounds (pairing 512 operations/128 slots/1 record; initial history 32/96/1; response 4096/256/1; impact 128/64/1), and checks cancellation before work and before return. Quanta count an upper bound on scalar arithmetic/comparisons and fixed record validation, not wall-clock latency. Borrowed inputs are not copied into arrays; no explicit per-evaluation workspace arrays/buffers. Compiler and standard-library allocation behavior is not measured; scalar-slot budgets cover component-owned workspace, excluding caller-owned immutable metadata buffers. Arithmetic overflow propagates typed failure; failed operations return no partial response.
## Verification and Change Impact
[tests](../../../Tests/MechanicsContactLawsTests/DESIGN.md) check rotation/power, invalid frames/kinds/nonfinite values, capacity/storage/work/cancel and accepted-history isolation. Changes affect all children and future IM21 adapters.
