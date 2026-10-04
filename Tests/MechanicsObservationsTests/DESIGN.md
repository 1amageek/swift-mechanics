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
Source count/oracles and actual executed evidence are supplied separately at handoff. No source/build success alone grants physical or target qualification. Changed mounting, compensation, provenance or temporal semantics requires affected oracle/profile requalification. AF30 independent Native evidence below applies only to its immutable owner snapshot; root registers and qualifies canonical/public composition separately.

The selected source contains 13 cases in four suites: KinematicObservationTests(3), IMUObservationTests(3), WrenchObservationTests(3), ObservationSourceTests(4). Static support uses actual spatial prismatic mass 2, gravity -10, and retained constraint row, yielding effort 20 and solved acceleration 0. Mounted rotation independently gives alpha-cross-offset/centripetal acceleration; quaternion 7/6 encoders expose storage/rate dimensions. Physical gravity compensation is literal input minus body gravity, with sign after subtraction. Their first actual execution is the AF30 independent proof below.

## AF30 source-association correction
reaction_paths owns the transferred test directory and four observation children. The same 13 declarations remain the compatibility cohort. Existing source/IMU cases add behavioral assertions for two concrete successful-supplier counterexamples: a composer returning stationary identity for a rotating mounted body, and a real original observer querying a different fixed mounting under unchanged sensor/body/frame headers. Both must fail `invalidSupplierEvidence`, retain admitted known work and leave original immutable inputs unchanged. Quaternion-sign-equivalent original orientation remains admissible; no floating tolerance, budget increase, new sensor or bearing decomposition is introduced.

Independent Native verification uses the root-assigned isolated committed-source proof slot and limited registration graph. Root owns canonical registration, public assertions and exact Native/ordinary WASM/Embedded composition with the original 131072-byte reservation.

### Executed independent Native evidence
The private `.build/af30-independent-observations` copy was created from immutable commit48cf8df without generated artifacts and overlaid only the four owned observation children and this test directory. Private registration admits the observation production sources, excludes their five DESIGN files, and retains only MechanicsObservationsTests; all production/executable targets, dependencies and compiler flags remain the baseline. The workspace manifest is unchanged by this owner.

Exact `/Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift`, `-j 4`, the original run_with_timeout.py and separate1200-second setup/240-second behavior limits were used. The smallest RED diagnostic removes only the two new acceptance blocks while retaining the unused new error symbol and real assertions; it is not an untouched historical source claim. Setup-red exited0 in20.12seconds; the two selected source/IMU cases exited1 in0.94seconds with exactly the unrelated-composer and changed-mount publication failures (`setup-red.log`, `red.log`).

Restoring the frozen corrected owner files byte-for-byte produced setup-green exit0 in7.33seconds and all13 cases/4suites exit0 in0.74seconds (`setup-green.log`, `tests.log`). The cohort includes the independent analytic physical oracles above plus in-case supplier-success refusals, quaternion-sign acceptance, reset after genuine computation on success/failure, and verification storage95 refusal for its declared96-slot envelope. Original immutable states remain unchanged on failure. `owner-freeze.json` records all owned source/test/design digests. Root public profiles and the original 131072-byte stack guards are pending separate composition evidence; this Native result does not close full SE-001..003 or IM25.
