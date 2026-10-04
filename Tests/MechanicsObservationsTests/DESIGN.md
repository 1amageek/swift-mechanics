# MechanicsObservationsTests

## Purpose and Scope
Selected IM25 behavioral evidence. Parent: [MechanicsObservations](../../Sources/SwiftMechanics/Analysis/Observations/DESIGN.md). No children.

## Responsibilities and Boundaries
Independent physical oracles for mounted geometric motion, chart quantities, IMU and identified force/impulse reads. Root owns actual registration/build/profile qualification. These queries do not qualify schedules or general reaction decomposition.

## Related Designs
[ObservationRecords](../../Sources/SwiftMechanics/Analysis/Observations/ObservationRecords/DESIGN.md), [KinematicObservations](../../Sources/SwiftMechanics/Analysis/Observations/KinematicObservations/DESIGN.md), [InertialObservations](../../Sources/SwiftMechanics/Analysis/Observations/InertialObservations/DESIGN.md), [WrenchObservations](../../Sources/SwiftMechanics/Analysis/Observations/WrenchObservations/DESIGN.md) own the tested contracts.

## Architecture
```text
actual compiled body/state and real mass solve -> public observation services -> independent analytic SI/frame oracle
```

## Contracts and Invariants
Fixtures use actual compiled spatial bodies, actual kinematic/composer and mass/constraint witnesses. Analytic expectations include independent offset acceleration, gravity difference, wrench moment and mass support balance. Rejected observation calls have no returned partial observation and preserve immutable inputs. Test work is exclusive to each test; no static mutable resource.

## Verification and Change Impact
Tests are unexecuted source until root registers the frozen snapshot. Source count/oracles and actual executed evidence are supplied separately at handoff. No source/build success alone grants physical or target qualification. Changed mounting, compensation, provenance or temporal semantics requires affected oracle/profile requalification.

The frozen source contains 13 cases in four suites: KinematicObservationTests(3), IMUObservationTests(3), WrenchObservationTests(3), ObservationSourceTests(4). Static support uses actual spatial prismatic mass 2, gravity -10, and retained constraint row, yielding effort 20 and solved acceleration 0. Mounted rotation independently gives alpha-cross-offset/centripetal acceleration; quaternion 7/6 encoders expose storage/rate dimensions. Physical gravity compensation is literal input minus body gravity, with sign after subtraction. No test has executed yet.
