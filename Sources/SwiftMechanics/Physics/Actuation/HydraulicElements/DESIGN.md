# Hydraulic elements

## Purpose and Scope
Parent: [Actuation](../DESIGN.md). Children: none. Selected AC-005/AC-008 fluid circuit services in the existing SwiftMechanics module: laminar resistance, turbulent orifice, ideal cracking check valve, fluid inertance, linear compliance and linearized double-acting cylinder. SI uses Pa, m3/s, m, m/s, N, J and W. No circuit solver, Runtime contributor or cavitation model is supplied.

## Responsibilities and Boundaries
Own immutable parameter admission, finite scalar constitutive response, exact instantaneous energy rates and original power residuals. Caller owns state and time integration; no accepted state or history is inferred. Gauge pressures for compliance/cylinder reference external reservoir pressure. Inertance uses incompressible lumped fixed geometry. Orifice assumes supplied constant density/discharge coefficient and no choking. Check valve is memoryless with explicit cracking pressure and zero reverse leakage; spool dynamics, hysteresis and reverse breakdown are outside its selected fidelity.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Actuation](../DESIGN.md) | parent | Fluid work/energy ownership | Selected AC services | Whole AC005 stays open |
| [Ports](../Ports/DESIGN.md) | depends on | Public ActuationWork, ActuationError | Resource/cancel refusal | Original supplier unchanged |
| [LumpedLaws](../LumpedLaws/DESIGN.md) | coordinates with | Linear-chamber approximation | Double chamber extends selected fidelity | No hidden migration of existing law |
| [Tests](../../../../../Tests/MechanicsSixHydraulicTests/DESIGN.md) | used by | Required public witnesses | Independent original energy/flow oracles | Native scope only |

## Architecture
```text
six independent immutable laws + caller-owned physical state
 -> exclusive ActuationWork preflight
 -> actual constitutive equations
 -> pressure/flow, storage rate, loss and raw power residual
```

## Contracts and Invariants
Every public operation is a non-generic required protocol witness. All scalar parameters and inputs finite; positive resistance, coefficient, density, area, inertance, compliance, volumes and bulk moduli. Nonfinite arithmetic fails without clipping. Zero pressure/flow remains meaningful. Bidirectional passive resistance must preserve nonnegative dissipation. Balance residual is calculated from independently evaluated original input and storage/loss powers, never replaced with zero.

| Element | Equations / sign convention | Admission |
|---|---|---|
| LaminarHydraulicResistance | q=dp/R; loss=dp*q | R>0, signed finite dp |
| TurbulentHydraulicOrifice | q=Cd*A*sign(dp)*sqrt(2*abs(dp)/rho); loss=dp*q | Cd,A,rho>0; sign at zero gives zero |
| HydraulicCheckValve | q=G*(dp-cracking) for dp>cracking, otherwise0; loss=dp*q | G>0, cracking>=0; no reverse conduction |
| HydraulicInertance | dp=I*dq/dt; E=I*q^2/2; Edot=I*q*dq/dt | I>0; caller supplies signed q and dq/dt |
| LinearHydraulicCompliance | dp=deltaV/C; E=deltaV^2/(2C); Edot=dp*q | C>0; signed deltaV relative to reference |
| DoubleActingHydraulicCylinder | C1=V1/B1,C2=V2/B2; leak=L*(p1-p2); p1dot=(q1-A1*v-leak)/C1; p2dot=(q2+A2*v+leak)/C2; F=A1*p1-A2*p2 | p1,p2>=0 within max pressure; signed bounded port flows; caller stroke/relative volume domain; L>=0 |

Cylinder constant reference compliances are an explicit small-volume-change approximation, not a nonlinear volume-dependent bulk model. Positive stroke expands chamber1 and contracts chamber2; positive flow enters each chamber. Check abs(Ai*stroke/Vi)<=caller maximumRelativeVolumeChange in(0,1), abs(stroke)<=maximumStroke. E=(C1*p1^2+C2*p2^2)/2. Source power=p1*q1+p2*q2; mechanical power=F*v; storage rate=C1*p1*p1dot+C2*p2*p2dot; leakage loss=L*(p1-p2)^2. Their original balance is exposed. No pressure clamping conceals invalid states. Each call uses a fixed scalar reserve16 (cylinder32) and fixed work charge32 (cylinder96) before arithmetic; storage/CPU are O(1), no arrays or allocations.

## State, Ownership, and Lifecycle
All models and returned samples are immutable Sendable values. Exclusive inout ledger retains actual attempted work on failure. No shared mutable state, pointer, callback emission, target-specific isolation or unsafe Sendable exists. Caller retains and integrates pressure, flow and relative volume state; services never mutate a previous sample.

## Failure, Concurrency, and Constraints
Existing ActuationError distinguishes invalidLaw, invalidInput, outsideDomain, nonfiniteResult, cancelled, capacityExceeded and workExhausted. Public bounded-work supplier is the sole cancellation/work authority. Cancel is checked on entry and before output. The six laws are independently callable and safe to evaluate concurrently with separate ledgers. Actual scalar-lib imports select platform math, not alternate semantics.

## Verification and Change Impact
Six separate parallel Native suites exercise independent constitutive equations, forward/reverse/zero and threshold branches, energy gradients or original coupled pressure/force power, parameter/domain/refinement and overflow failures. Common tests exercise actual supplier capacity, work exhaustion and cancellation plus preserved immutable results. Cylinder original small-volume domain and reservoir-relative convention are tested explicitly. Source hashes bind evidence to merge; unchanged work suppliers retain their proof. Formula-local change invalidates its suite; common sample/preflight change invalidates all. Native evidence cannot qualify WASM/Embedded, full circuit evolution, absolute-fluid thermodynamics or full AC005.

Selected Native evidence: canonical MechanicsSixHydraulicTests built with the Swift 6.4.0 release toolchain and passed41 original behavioral tests in seven concurrent suites on macOS27.0.1 arm64. Twenty-one production/test Swift files are frozen with SHA-256 receipts;23 actual work/actuator/numerical/identity supplier files match main unchanged. Original mechanical port mapping was executed with the actual published ActuationTransmitting witness. No full circuit/Runtime or portable qualification is implied.
