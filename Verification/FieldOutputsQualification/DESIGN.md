# Selected Tet4 physical field qualification

## Purpose and Scope
Parent: [FieldOutputs](../../Sources/SwiftMechanics/Physics/Flexible/FieldOutputs/DESIGN.md). No children. Own independent analytical fixtures, shared public protocol cases, Native test adapters, standalone entry point and private qualification artifacts. Root owns shared graph registration, supplier compilation, resource leases, cumulative verification and Git. Reuse the immutable historical Native2363 producer depot; no cold producer or full SDK restoration.

## Responsibilities and Boundaries
Drive the actual existential `Tet4FieldComputing` evaluator/sample/average/assemblyDiagnostics operations, after real public mesh validation. Supply a beta-zero polynomial material with bulk modulus12Pa, shear modulus3Pa, maximum Green-strain norm0.5 and minimum J0.2. Its assigned law is linear in Green strain within that declared envelope, with first Piola and Cauchy derived by actual finite-strain kinematics. Derive expected tensors, energy and energy-gradient forces independently from explicit F, reference volume1/6m3 and reference shape gradients. Do not reuse field or Tet4 internal helpers, replace the assembler, invent nodal stress recovery, or generalize to nonlinear material/history or rotations outside the declared domain.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [FieldOutputs](../../Sources/SwiftMechanics/Physics/Flexible/FieldOutputs/DESIGN.md) | parent, depends on | Tet4FieldComputing and immutable source/snapshot | Actual field producer | Historical producer/source correspondence is required |
| [Mesh](../../Sources/SwiftMechanics/Physics/Flexible/Mesh/DESIGN.md) | depends on | TetrahedralMeshValidating and validated mesh | Original positive-volume Tet4 geometry | Public qualified values only |
| [Tetrahedra](../../Sources/SwiftMechanics/Physics/Flexible/Tetrahedra/DESIGN.md) | depends on | Actual TetrahedralAssembling through diagnostics | Real force/energy comparison | No synthetic assembly or precomputed force supplier |
| [Elasticity](../../Sources/SwiftMechanics/Physics/Materials/Elasticity/DESIGN.md) | depends on | PolynomialHyperelasticity, HyperelasticResponding | beta-zero Green-strain response | No claim outside the chosen envelope |

## Architecture
```text
original finite reference nodes + explicit material/source/frame
 -> real public mesh validator -> immutable Tet4FieldSource
 -> public field evaluate with current affine positions/rates/time/revision
 -> sample and explicit cell/material averaging
 -> actual public Tet4 assembler through assemblyDiagnostics
 -> independent analytical tensor/energy/nodal-force/power assertions
 -> identical synchronous protocol cases in Native tests and standalone
```

## Contracts and Invariants
All positions/displacements are meters; E and F are dimensionless, P/S/Cauchy are Pa, stored energy J, density J/m3 of reference volume, internal force N and power W. The internal force is the positive energy gradient, not a restoring force. The standard reference Tet4 has original gradients `g0=(-1,-1,-1),g1=X,g2=Y,g3=Z` and volume1/6. Published global moment origin must equal the actual current first mesh-node position. Mesh/material/cell/source/node/frame/time/revision and exact source owner remain attributable and immutable.

| Oracle | Shear F=(I with Fxy=1/5) | Volumetric F=(11/10)I |
|---|---|---|
| J | 1 | 1331/1000 |
| E | Eyy=1/50, Exy=Eyx=1/10, other entries0 | (21/200)I |
| S | [[1/5,3/5,0],[3/5,8/25,0],[0,0,1/5]] | (189/50)I |
| P | [[8/25,83/125,0],[3/5,8/25,0],[0,0,1/5]] | (2079/500)I |
| Cauchy | [[283/625,83/125,0],[83/125,8/25,0],[0,0,1/5]] | (189/55)I |
| Reference energy density | 79/1250 | 11907/20000 |
| Stored energy | 79/7500 | 3969/40000 |
| Internal power for declared H | 319/7500 | 693/4000 |

Expected formulas are `lambda=10`, `S=lambda*tr(E)I+6E`, `psi=5*tr(E)^2+3*(E:E)`, and `fi=(1/6)*P*gi`. The declared rate H has Hxx=1/10, Hxy=3/10, Hyy=-1/20, Hzz=1/5. Add arbitrary uniform current translation and nodal velocity `(1,-2,1/2)`; net force, current moment and uniform-velocity power must cancel independently. The energy directional derivative uses the fourth-degree explicit beta-zero polynomial along F+tH; a symmetric four-point derivative of independently evaluated actual energies checks the positive force sign and energy relation, while the original analytical P:H value remains the oracle.

For exact +90-degree Z rotation R, pure F=R has E=0 and zero stress/energy. For F=R*Fshear, E/S/energy are unchanged, P rotates on its spatial index and Cauchy rotates both spatial indices. These cases remain inside norm0.5; shear Fxy=2 must return the original strain-domain failure with spent real constitutive-call count, and J below0.2 must retain the original material-volume failure when field admission allows it. No broader objective finite-rotation validity follows.

Sampling at node and interior material coordinates must preserve constant cell stresses but interpolate actual reference/current position, displacement and prescribed velocity. Two disjoint positive Tet4 cells retain distinct material records; the second reference cell has x-edge2m and volume1/3, with twice the moduli and volumetric F. Reference-volume reporting weights are1:2; current-volume weights are1:2662/1000. Explicit material blend reports weighted tensors/density and the exact unweighted sum of selected stored energies. Requiring the same material must reject this pair; no stress continuity or homogenized material is asserted.

## Runtime Flows
Public input admission -> separate numerical and real material-call work -> fields -> independent physical assertions -> sample/average -> real assemblyDiagnostics -> original per-node force and energy assertions. The assembler consumes thirteen public constitutive operations per Tet4 (one evaluate and twelve tangent calls), distinctly from one evaluate per cell in field output. Failure keeps spent ledgers and publishes no partial snapshot. Measure late cancellation by the same noncancelling callback sequence, then cancel on its final checkpoint with fresh work; actual Native Task cancellation uses prepared immutable inputs and an awaited Task with its original untyped throwing adapter boundary.

## State, Ownership, and Lifecycle
All fields, source/snapshot owners and fixture inputs are immutable Sendable values; work/call ledgers and coordinate/force arrays are call-local. The cancellation counter alone owns shared callback state, protected on all targets by the same `Synchronization.Mutex<Int>` and withLock read/increment paths. No await/I/O/external callback under that lock. Native consumer minimum macOS15 reflects Mutex availability; historical producer target13 remains unchanged. Test adapters import the same support sources; platform composition does not alter state or failure semantics. Immutable depot objects/module remain read-only and individually SHA validated before/after execution.

## Failure, Concurrency, and Constraints
Typed qualification failures preserve original FieldOutputError/FlexibleError/MaterialError/CoreError/ModelError/NumericalError. Verify stale source owner/time/geometry/layout/frame, malformed material coordinates, missing/duplicate cells, invalid material averaging, unsupported logarithmic stress/nodal smoothing, inversion/strain/material volume failures, invalid policy/time, count/identifier/scalar/operation/call budgets, late and actual Task cancellation. Narrow fixture-only compile/link uses pinned Native6.4.0 with actual effective jobs4, external watchdogs and additional cache budget256MiB beyond the immutable depot. Strict signature results are separate from runtime evidence. A real owned production defect requires causal design/source repair and freshly matching producer objects; never mix new source with the old module.

## Verification and Change Impact
Fix physical oracles and failure cases above before source edits. One source review plus causal repair/recheck if evidence requires it; same six synchronous public cases in Swift Testing and standalone, plus actual Task cancellation adapter. Native depot receipt and source SHA define the historical graph; do not claim the live graph is identical. Per-feature portability preparation later uses the exact registered committed baseline, original exclusions, only frozen FieldOutputs16 and unchanged fixture sources; no heavy profile executes without root's ordered lease. Source/material/geometry/force sign/domain changes invalidate their affected physical witnesses. New element families, nonlinear materials, history/evolution, stress recovery and full flexible qualification remain separate contracts.

### Native evidence and portability preparation premises
The selected historical Native2363 proof completed with seven Swift Testing cases (including awaited actual Task cancellation) and the same six synchronous public cases. Actual effective fixture driver jobs4; original depot2363 objects and three metadata plus selected original/live FieldOutputs16 and unchanged fixture sources were individually hash validated before and after. Native receipt: `.build/af35-field-outputs-qualification/native-qualification-receipt.json`, SHA256 `1a5061dfc13b82cab949b49f4c86aa2c023f1b5190c4f5f22c017ac5cc653e7f`. Cache187542030bytes remains within256MiB. Strict public signature passed; generated test bundle strict signature returned the preserved resource-signature mismatch, separately from successful runtime. Relocated producer PCM paths cause dSYM warnings; original producer sources/module/objects remain matching, and no source diagnostics or production repair occurred. This receipt covers the pre-execution DESIGN copies preserved in the private directory; the following preparation changes documentation only.

Prepare the exact committed4d16dfdeed329eb425f8f54dc171793903bc55e5 baseline from `.build/af35-committed-baseline-4d16dfd` (inventory SHA256 `6ce46bfe113b64f48957d91d9d49d259ab85ce1dc2b5e1f224e16f2cd0e1d25c`), preserving every original production file and original exclude entry. Add only unchanged FieldOutputs16 plus its DESIGN (excluded as documentation), for1562+16=1578 included SwiftMechanics sources. Keep the same eight fixture Swift bytes, separated into support/public/test targets; standalone executes the same six synchronous public cases. Profile proof is independent of the historical Native2363 source graph.

Pinned Swift6.4.0 and matching ordinary/Embedded WASI SDK IDs retain wasm32-unknown-wasip1, WMO in Embedded, actual jobs4 and frontend thread4, and the same immutable Sendable/Mutex semantics. Reuse attributable original SDK configuration/library inspection, distinguishing that past inspection from current SDK installation (which can be archived by the resource owner). Ordinary SDK has no separately named Unicode tables archive and receives no EmbeddedUnicode trait; matching Embedded SDK links its real Unicode tables archive with EmbeddedUnicode. No Unicode/parser/source semantics substitution is allowed. Preparation copies/records only sources, manifest, per-file SHA and frozen timeout/stack-guard/WASI helpers. Cold compile/link, full decode, guard/raw execution, SDK restore and archive changes require root's ordered resource lease; none are executed by this preparation. Existing Native evidence remains valid because fixture/production Swift bytes are unchanged.


### Complete registered Native1960 composition evidence

The root executed committed base `f4fbd23720788666d359cba8d8764994be196be5` containing all1944 registered production Swift files plus the same original FieldOutputs16: actual full1960. The original eight fixture Swift files, six physical/public cases, numerical tolerances, typed refusal/work checks and seventh awaited Native Task cancellation test remain unchanged. Exact per-file authority is [canonical-expected-source-freeze.json](../../.build/af35-field-outputs-qualification/registration/canonical-expected-source-freeze.json), SHA256 `66fa1e178679f733f7c0d95eab2b04b568f527e65ab8102d993062ce2eafb185`. Historical Native2363 evidence remains separate and is not substituted for this composition proof.

| Owned proof boundary | Actual completed evidence |
|---|---|
| Complete production source/module | All1960 actual source-list paths equal the frozen graph, source-list SHA `f38875a091845461430b62d20405a7047384dcc01316c923c7c7a0e9e37b0217`; actual16 subject primaries and complete1960 module emission are retained |
| Original producer source to fresh objects | [canonical-production-object-inventory.json](../../.build/af35-field-outputs-qualification/registration/canonical-production-object-inventory.json), SHA `2b9598107744f18c32fbc720d8ca0d72ee0bedc38b8e98fd3365f5da03c6b043`: all1960 source/object identities plus three matching production module metadata, rechecked after runtime |
| Actual fixture objects and runtime library | [canonical-fixture-object-link-bindings.json](../../.build/af35-field-outputs-qualification/registration/canonical-fixture-object-link-bindings.json), SHA `a66a9349b712e4f9782a9b44f0a4d0bc023836a42e64249b2afa3f0fd22652ce`: original six support objects and test object actually linked, original public object bound; fresh full1960 library SHA `7d6c81d48aa383eefac7447621592421cece3f053d0a644f089d01000331b4e3`, support module and actual loaded-library inspection retained |
| Selected original behavior | [canonical-native-receipt.json](../../.build/af35-field-outputs-qualification/registration/canonical-native-receipt.json), SHA `41ae493c19115f540909375d940bb834e24772c51c1bf8904033891a26ad8cf1`: seven Native tests and same six public cases passed; public output equals original six lines exactly |
| Target, synchronization and operational bounds | Pinned Swift6.4.0 RELEASE and matching MacOSX27.0 SDK; actual producer arm64-apple-macosx13.0, unchanged fixture consumer arm64-apple-macosx15.0 for its original Mutex, final effective jobs4;128MiB additional envelope,896MiB admission,768MiB floor with16MiB reaction margin and command deadlines |
| Signature limitation | Public and fresh library strict signature verification exited0. Generated test bundle strict signature exited1 with its existing resource-signature discrepancy, separately retained from successful test/runtime behavior; no all-signatures-green claim |

No production16 or fixture8 Swift was changed. Shared registration, parent documents, commit and cumulative integration belong to root. This proof qualifies selected Tet4 beta-zero declared Green-strain-domain field measures, original force/energy/power, sampling/averaging and resource/source/refusal/cancellation cases. It does not establish finite-strain objectivity, arbitrary nonlinear/material/element domains, flexible evolution or ordinary/Embedded execution, performance or stack safety. No redundant behavior rerun accompanies these documentation updates.
