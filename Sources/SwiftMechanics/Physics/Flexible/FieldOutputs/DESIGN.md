# Tet4 Field Outputs

## Purpose and Scope
Own AF35.2 selected FX-010 physical fields for the qualified IM19 constant-F Tet4 polynomial-hyperelastic domain. Parent: [Flexible](../DESIGN.md). No children. Assigned [public qualification](../../../../../Verification/FieldOutputsQualification/DESIGN.md) owns selected behavioral evidence; cumulative qualification and commit remain root-owned.

## Responsibilities and Boundaries
Reconstruct current F from public reference geometry and nodal positions; call the assigned public HyperelasticResponding law; identify strain/stress/displacement/energy and positive energy-gradient internal-force fields. Own bounded material-coordinate sampling, explicit descriptive mesh averaging and diagnostics against actual public Tet4 assembly. Mesh/material/evolution authority remains with qualified suppliers. Field averaging is a declared reporting operation, not an effective material or nodal stress recovery model.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Flexible](../DESIGN.md) | parent | FX-010 reporting | Composition | Other element families remain outside this API |
| [Mesh](../Mesh/DESIGN.md) | depends on | ValidatedTetrahedralMesh, public inverse edges/gradient0…3 | Physical geometry/assignment | Consumer never accesses internal helper methods |
| [Tetrahedra](../Tetrahedra/DESIGN.md) | depends on | NodalState, TetrahedralAssembling, FlexibleAssembly | Actual equation comparison | Assembly has no source/state stamp, so diagnostics invoke it on this exact retained source/state |
| [Elasticity](../../Materials/Elasticity/DESIGN.md) | depends on | HyperelasticResponding.evaluate and fixed assigned law | Actual P/S/Cauchy/energy | No provider substitution or constitutive history |
| [Constitutive](../../Materials/Constitutive/DESIGN.md) | depends on | SymmetricTensor/FiniteStressResponse | Tensor measures | Green strain is dimensionless; energy density is per reference volume |
| [Core](../../../Mathematics/Core/Geometry/DESIGN.md) | depends on | Public Matrix3/Vector3 arithmetic | Consumer-owned field reconstruction | Fixed-size finite arithmetic |

## Architecture
```text
qualified validated Tet4 source owner + current identified NodalState/time/epoch
 -> bounded admission -> current edges * public inverse reference edges
 -> actual assigned HyperelasticResponding.evaluate -> constant cell fields
 -> V_reference P gradN / V_reference psi -> identified nodal force and energy
 -> immutable physical snapshot -> material-coordinate sample / explicit mesh average
                              -> actual public Tet4 assembly -> original diagnostics
```

## Contracts and Invariants
F is constant within each linear Tet4; material-coordinate location changes interpolated position/displacement, not cell strain/stress. Current cells require positive volume and explicit volume-ratio admission plus the assigned law's strain domain. Output positions/displacements use meters, stress Pa, energy J, energy density J/m cubed of reference volume, force N, time seconds in the mesh frame. P=FS and Cauchy=P F transpose/J are accepted against original public response; E=(F transpose F-I)/2 is independently reconstructed. F from edges must agree with sum of current nodal positions outer reference gradients. Internal force is the positive energy gradient V_reference P gradN; restoring evolution would subtract it. Net force/current moment and internal nodal power versus V_reference P:Fdot are checked at the field operation. Cell moments use the current first cell node; global/assembly moments use the snapshot's published current first mesh-node origin, avoiding an implicit world-origin convention. Sampling/averaging recheck original measure transforms under their own operation tolerances without inventing additional constitutive calls.

Sampling admits four barycentric coordinates and an identified cell/mesh revision. Projection is explicit element-constant; nodal smoothing and logarithmic stress are callable marked failures. Mesh averaging explicitly selects unique cells, reference/current-volume weights and either one identified material or explicitly allowed material mixing. It reports weighted stress/Green strain/displacement/reference energy-density values and separately exact sum of selected stored energies; no smoothness, constitutive homogenization or integrated meaning is assigned to averaged density under current-volume weights.

## Runtime Flows
Count/metadata/storage preflight -> exact frame/revision/node-order and previous owner/time/epoch admission -> each current cell F -> charged actual material call -> original measure and force/power checks -> immutable snapshot. Sampling and averaging re-admit relevant current policy and preserve source/location/measure/projection/weight metadata. Assembly diagnostics preflight simultaneous snapshot and dense supplier storage, invoke actual public assembly on retained inputs, compare per-node forces/energy/resultants, and publish only accepted residuals. Cancellation gates precede supplier calls and every output. No retry, fallback or state advancement occurs.

## State, Ownership, and Lifecycle
Immutable Sendable source/snapshot/field/sample/average/diagnostic values retain physical mesh, material assignments, state, time and geometry revision. Exact source owner prevents reused revision numbers from inheriting previous-state authority. Numerical and field-constitutive work are exclusive operation-local/caller inout; no shared cache, pointer, target branch or mutable accepted history exists. The published ConstitutiveCallWork has no public charge method; FieldOutputs owns its own real evaluate-call ledger and uses the supplier's ledger only when invoking public assembly.

## Failure, Concurrency, and Constraints
Caller bounds nodes/cells/materials/locations/metadata/scalar storage and sets separate deformation/strain/stress/volume/force/moment/power/energy tolerances. Checked products/sums precede allocation. Known outer arithmetic is charged independently from actual public constitutive calls; unpublished material internal arithmetic is not fabricated. Failure preserves spent work/calls and returns no partial field. Invalid location, duplicate selection, mixed-material rejection, unsupported measure/projection, stale owner/epoch/layout/frame, inversion, material-domain failure, nonfinite arithmetic, resource exhaustion and cancellation return typed errors. Structural storage bounds do not establish measured allocator or wall-time behavior.

## Verification and Change Impact
Assigned qualification fixes independent affine shear/volumetric Green-strain oracles for beta-zero material within the declared strain norm and volume-ratio envelope, rigid rotations remaining inside that envelope, analytic P/E/Cauchy/reference energy, constant-cell location invariance with affine displacement, multi-material discontinuity and explicit averaging, actual assembly force/energy comparison, nodal versus P:Fdot power, inversion/domain/frame/layout/epoch/location/call-budget and late cancellation. Its exact historical Native2363 producer is distinguished from the later live cumulative graph. Behavioral and portability results belong to its receipts; source compilation alone does not qualify these equations. No general nonlinear-material or out-of-domain objective finite-rotation claim follows from selected beta-zero fixtures. Supplier geometry/material equations or force sign changes invalidate this consumer. New element families, history/evolution or stress recovery need their own supplier and reporting contracts.


Selected Native behavioral qualification is recorded by [the fixture owner](../../../../../Verification/FieldOutputsQualification/DESIGN.md). The original Native2363 receipt remains historical. Actual complete registered Native1960 composition now binds all1944 committed base sources plus unchanged FieldOutputs16 to matching fresh objects/module/library and original fixture8 source/object/link paths. Its seven actual tests (including awaited Task cancellation) and six identical synchronous public cases passed for the chosen Tet4 beta-zero declared Green-strain-domain measures, source/failure/work budgets and original assembler diagnostics. Producer macOS13 and unchanged Mutex fixture macOS15 are explicit; strict public/library signatures passed while the original test-bundle resource discrepancy remains separately recorded. This selected evidence does not establish finite-strain objectivity, other element/material/evolution domains or ordinary/Embedded execution, performance or stack safety. Production16 and fixture8 Swift remain unchanged; the fixture design owns exact frozen receipt and source/object/link hashes.
