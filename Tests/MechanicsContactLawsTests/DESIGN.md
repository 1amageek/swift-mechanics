# Contact law verification
## Purpose and Scope
Test owner for [Inputs](../../Sources/SwiftMechanics/Physics/ContactLaws/Inputs/DESIGN.md), [MaterialPairs](../../Sources/SwiftMechanics/Physics/ContactLaws/MaterialPairs/DESIGN.md), [Response](../../Sources/SwiftMechanics/Physics/ContactLaws/Response/DESIGN.md), [Impact](../../Sources/SwiftMechanics/Physics/ContactLaws/Impact/DESIGN.md). Children: none.
## Responsibilities and Boundaries
Independent scalar equations, vector rotations, traction work/energy and failure oracles. No collision, body integration or coupled solver fixture implies those paths are implemented.
## Related Designs
All four component links above own their contracts. Core/Model actual public values are fixture producers; test-only constructors do not fabricate material/law results.
## Architecture
```text
explicit SI parameters -> production protocols -> independent force/energy/cone/power oracles
accepted values -> successful and rejected trials -> replay/isolation checks
```
## Contracts and Invariants
Float64 native fixtures use m/N/J/s scales, reference energy/power 1 J/1 W. Finite-difference normal derivative oracle uses 1e-8 m perturbations and 0.001 N/m absolute tolerance. Scalar/vector oracle tolerance 1e-9 absolute +1e-10 relative; production acceptance freezes 1e-10 J/W absolute +1e-11 relative and 1e-11 dimensionless cone. Normal envelopes are fixture-selected finite values; Hertz delta<R. Curves, static onset/slip, anisotropic scene rotations, resistance and cohesive opening work have independently computed answers. Invalid material/normal envelope/frame/time/history/pair/budget/cancel cases fail explicitly.
## Verification and Change Impact
Run only after target registration: python3 Scripts/run_with_timeout.py 180 swift test --build-path .build/contact-laws-kernels --filter MechanicsContactLawsTests. Shared mutable resources: none. Every fixture owns its local work/history. Root owns separate exact Native/WASM/Embedded composition; local success does not close eventual CT models, full drop/impact refinement, distributed patches or coupled dynamics.

MaterialSiteTests owns same-body distinct material-feature admission, actual normal/friction force and discrete energy/power, immutable replay, ordered site and topology-revision stale rejection, long-key budget rejection, exact extra scalar storage and unchanged legacy budget. It does not prove deforming geometry or nodal dynamics.
