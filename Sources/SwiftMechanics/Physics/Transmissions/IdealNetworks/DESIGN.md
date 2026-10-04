# IdealNetworks

## Purpose and Scope
Parent [MechanicsTransmissions](../DESIGN.md); no children. Affine gear/rack/shaft/no-slip pulley/Willis coordinate and conjugate-effort networks, consuming actual IM12 equations/assembly. Initial TR-001/003 and selected TR-005/006/008 portions. Full TR-001..011 ownership remains after this closed initial handoff.

## Responsibilities and Boundaries
Own the contract below; consumer owns constrained evolution, model/snapshot binding and dynamic reaction solve. Tooth/contact geometry belongs to IM47, not this ideal ratio or constitutive port.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [Parent](../DESIGN.md) | parent | IM13 ownership | Initial subset only |
| [Bindings](../PortBindings/DESIGN.md) | depends on | Frame/axis/map and work units | Snapshot authority stays with caller |
| [Coordinates](../../Constraints/CoordinateEquations/DESIGN.md) | depends on | QuadraticConstraintSystem | Normalized chart preserved |
| [Assembly](../../Constraints/AssemblyProjection/DESIGN.md) | depends on | Required assembly and rank | KKT multiplier is geometric |
| [Compliant](../CompliantPorts/DESIGN.md) | used by | Physical rows | Backlash does not enforce ideal closure |
| [Tests](../../../../../Tests/MechanicsTransmissionsTests/DESIGN.md) | used by | Ratio/phase/work/closure proof | Root owns exact profiles |

## Architecture
```text
relation + ports -> physical affine row -> normalized IM12 equation -> assembly or supplied multiplier effort -> original row/power acceptance
```

## Contracts and Invariants
External spur: N1*q1+s*N2*q2-phase=0; internal: N1*q1-s*N2*q2-phase=0, where s is signed parallel-axis orientation. Rack: x-sign*r*q-phase=0; direction must be perpendicular to pinion axis. Rigid shaft: q1-s*q2-phase=0. Open pulley: r1*q1-s*r2*q2-phase=0; crossed uses plus. Willis: Ns*qs+Nr*sr*qr-(Ns+Nr)*sc*qc-phase=0, parallel axes in sun reference. Each physical phase has declared angle/length dimension and positive phaseScale; compile normalized row ci*Si/phaseScale into actual QuadraticConstraintSystem, preserving every row. Supplied normalized multiplier is energy datum lambda; generalized effort Qi=sum(lambda*ci/phaseScale). These multipliers are caller-supplied physical effort data, never assembly geometric KKT multipliers or inferred dynamic reactions. Original physical phase/speed residuals and ideal power are independently checked. Closed-loop assembly invokes verified required ConstraintAssembling once with a separate ledger and independently rechecks physical rows; rank/ambiguity remain supplier evidence. No global tooth phase modulo, tension/slack/contact or bearing force model is claimed.

## Runtime Flows
Admission precedes bounded traversal/allocation. Local non-inlined phases retain fixed stack boundaries. Supplier failure halts once; no retry/substitution. Final cancellation check precedes publication.

## State, Ownership, and Lifecycle
Immutable compiled records own persistent physical and normalized coefficient vectors. All affine rows share one immutable zero Hessian and mixed-time vector. Peak admission is n²+2*m*n+64*m+2*n scalar-equivalent slots for compile, n+64*p for effort output. Checked products precede allocation; no per-inner-loop arrays. Caller position/domain/port backing remains immutable. Bindings owns shared lifetime/work conventions.

## Failure, Concurrency, and Constraints
Consume [Bindings work/cancellation authority](../PortBindings/DESIGN.md). Separate constraintWork retains known outer assembly work. Assembly failure is distinguished from direct scalar-port failure by TransmissionError.assembly, retaining the underlying ConstraintError and failedSupplierWorkUnavailable. A nonlinear failure carries its actual work and nested failed-supplier flag; a direct linear failure preserves its supplier flag. Other assembly failures conservatively mark unavailable supplier work, because a post-solve original/correction/rank check can discard successful nested solver diagnostics. The retained inout ledger must not be presented as the total in those cases. Failure stops once without retry/substitution. Caller domains/revisions and original phase/speed/power tolerances govern acceptance. Selected extended fidelity has an INCOMPLETE_IMPLEMENTATION marker and explicit unsupported failure. Invalid counts/radii/axis geometry or contradictory original closure cannot publish a network solution. No inferred dynamic reaction, tooth placement, or bearing capacity.

## Verification and Change Impact
Signed external/internal 20:40 phase, opposed axes, rack dimensioned work, open/crossed pulley, Willis power, real redundant idler-loop assembly and contradictory loop, original speed rejection even with zero multiplier. Row/effort changes affect IM16 and the CompliantPorts physical-phase consumer.
