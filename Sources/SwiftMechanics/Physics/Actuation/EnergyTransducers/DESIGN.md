# Energy transducers

## Purpose and Scope
Parent: [Actuation](../DESIGN.md). Children: none. Selected AC004/AC008 energy-based lumped electromechanical constitutive services: voice coil, reluctance solenoid, salient-pole reluctance rotor, linear piezoelectric, parallel-plate electrostatic and linear-capacitance comb drive. Existing SwiftMechanics module, no new package or foreign implementation.

## Responsibilities and Boundaries
Own immutable constitutive parameters, supplied canonical electrical state, force/torque, conjugate electrical effort, analytic reciprocal tangent and instantaneous field/storage/mechanical/loss/source power. State/time integration, drive control, Runtime acceptance, circuit solves, magnetic saturation, ferromagnetic hysteresis, fringing, dielectric breakdown and manufactured geometry are separate responsibilities. Capacitive laws assume calibrated ideal electrostatics. Magnetic laws assume calibrated linear magnetics. No inductance is inferred from CAD.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Actuation](../DESIGN.md) | parent | Law/port energy ownership | Selected AC services | Whole AC004 remains open |
| [Ports](../Ports/DESIGN.md) | depends on | ActuationWork/Error, public affine mechanical mapping | Original budget/failure authority | Caller owns model/frame association |
| [Loads PassiveLaws](../../Loads/PassiveLaws/DESIGN.md) | depends on | ScalarCoordinateKind | m or unwrapped rad | No framed authority inferred |
| [Tests](../../../../../Tests/MechanicsSixTransducerTests/DESIGN.md) | used by | Required protocol witness and real affine service | Independent energy/gradient/power tests | Native evidence only |

## Architecture
```text
six independent immutable calibrations + q and electrical canonical state s
 -> original E(q,s), F=-E_q, e=E_s, analytic tangent
 -> caller rates -> drive effort / independently calculated source power
 -> original field, storage, mechanical and loss powers
 -> caller-identified real affine mechanical port
```

## Contracts and Invariants
All scalar parameters/inputs finite. Magnetic state is flux linkage s [Wb-turn], conjugate effort e is current [A]. Capacitive state is charge s [C], e is voltage [V]. Mechanical q is m or rad, F is N or Nm. Coupling=F_s=-e_q, mechanicalTangent=F_q, electricalTangent=e_s. Stored energy is nonnegative; electrical tangent positive. Signed coupling defines orientation. Query domains are explicit below; invalid/nonfinite arithmetic is refused.

| Model | Original energy and admitted parameters | Domain |
|---|---|---|
| VoiceCoilTransducer | E=(s-k*q)^2/(2L); L>0, signed nonzero k; series resistance R>=0 | finite q,s |
| ReluctanceSolenoid | E=s^2*(g0-q)/(2a); a=inductanceLengthProduct [H*m]>0; g0>minimumGap>0; R>=0 | g0-q>=minimumGap |
| SalientPoleReluctanceMotor | L=L0+Lh*cos(n*q); E=s^2/(2L); L0>abs(Lh), n>0 exactly representable integer; R>=0 | finite unwrapped q,s; no wrap |
| PiezoelectricTransducer | E=(s-d*q)^2/(2C)+K*q^2/2; C,K>0; signed nonzero d; parallel leakage G>=0 | finite q,s; calibrated linear piezoelectric regime |
| ParallelPlateElectrostaticActuator | E=s^2*(g0-q)/(2*epsilon*A); epsilon,A>0; g0>minimumGap>0; G>=0 | g0-q>=minimumGap; no fringing |
| ElectrostaticCombDrive | C=C0+c*q; E=s^2/(2C); C0>0; signed nonzero c; G>=0 | caller finite min<max q; positive finite C at both endpoints |

Power sample caller supplies qdot and sdot. Drive effort is sdot+r*e: terminal voltage for magnetic state, terminal current for capacitive state. SourcePower=e*driveEffort is computed independently; mechanicalPower=F*qdot; storagePower=-F*qdot+e*sdot; physicalLoss=r*e^2. The raw source-mechanical-storage-loss residual is retained. R/G are explicit passive loss coefficients; no loss or zero residual is manufactured. A caller holding current or voltage must supply a compatible canonical-state rate, including coupling; the API does not silently hold the conjugate effort.

Sample contains no source identity. Actual affine integration requires explicit model/frame from the caller and preserves the original supplier's authority. A mechanical scalar map is an instantaneous force port, not electrical integration or prescribed motion.

## State, Ownership, and Lifecycle
All public values immutable Equatable/Sendable. No cache, pointer, mutable reference, target-dependent isolation or accepted-state mutation. Each call consumes an exclusive inout ActuationWork. State is supplied and retained by the caller. Six formulas may run concurrently using independent ledgers.

## Failure, Concurrency, and Constraints
Existing ActuationError invalidLaw/invalidInput/outsideDomain/nonfiniteResult/cancelled/capacityExceeded/workExhausted are preserved. Original work supplier preflights scalar reserve24 and work64 before model arithmetic; power evaluation reserve16/work32. Each method checks cancellation before publication. O(1) scalar arithmetic, no retained storage or arrays. Scalar-lib imports select actual math availability; Native qualification does not imply WASM/Embedded.

## Verification and Change Impact
Six named concurrent suites independently check original physical examples, central energy gradients, every reciprocal tangent at h1e-5/5e-6, signed rates and real existing affine mechanical mapping. Common tests cover invalid rates, original ledgers, capacity, exhaustion and cancellation. Original-value tolerance1e-10abs+1e-9rel; numerical gradients1e-7abs+2e-5rel, fixed before execution. No Runtime/circuit/saturation/field-solver or minimum-platform/performance claim. Changed common sample invalidates all suites; model-local formula change invalidates its own. Freeze source/tests and unchanged actual suppliers before merge.

Selected Native evidence: canonical MechanicsSixTransducerTests built with Swift6.4.0 release on macOS27.0.1 arm64 and passed40 behavioral tests in seven concurrent suites. Original values, all energy gradients/reciprocal tangents, signed power, domain/overflow and actual published affine mechanical ports executed. Nineteen production/test Swift files are SHA-256 frozen;23 original public work/actuator/identity/numerical suppliers match main unchanged. First run exposed one independent comb-drive reference arithmetic error; correcting -0.5 to -1 changed no implementation or tolerance. Native receipt does not qualify circuit/Runtime/time integration, saturation/hysteresis/fringing/breakdown or portable/minimum-platform/performance.
