# MechanicsContactResponseTests

## Purpose and Scope
Native behavioral proof owner for initial IM21 WitnessPorts and ImplicitNormal. Parent [package](../../DESIGN.md); no children.

## Responsibilities and Boundaries
Own analytic effective-mass/normal/momentum/wrench and failure fixtures. Root owns exact-profile composition and commits.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Ports](../../Sources/SwiftMechanics/Physics/ContactResponse/WitnessPorts/DESIGN.md) | depends on | Framed adapter | Identity/geometry proof | Closed normal domain |
| [Response](../../Sources/SwiftMechanics/Physics/ContactResponse/ImplicitNormal/DESIGN.md) | depends on | Coupled response | Original mechanics | Frozen geometry only |

## Architecture
```text
actual Collision/Dynamics/ContactLaws suppliers -> public response protocols
independent analytic contact equations -> compare force/velocity/residuals
```

## Contracts and Invariants
Actual rigid snapshots/witnesses/law pairs and accepted immutable history are used; no producer placeholder. Original equations independently checked.

## Failure, Concurrency, and Constraints
Local fixtures/ledgers; timeout180 and private .build/contact-response-kernels. Any mutable cancellation fixture uses Mutex with platform availability.

## Verification and Change Impact
Effective mass, coupled compliance, dependent rows, normal residual, frame/lever arm/power/momentum, stale/unsupported/budgets/cancel/supplier failures. Only selected initial profile qualified; root owns other targets.

Native evidence: timeout180 `swift test --build-path .build/contact-response-kernels --filter 'CoupledNormalTests|ResponseFailureTests'` exited 0 with ten tests in two suites passing, recorded in `.build/contact-response-kernels-focused.log`. The mass response uses actual Dynamics services; independent analytic single/stack/hinge equations and original normal-law rejection exercise the physical path. Current proxy mask veto and long-key admission are included in the failure fixtures. This evidence does not qualify full contact evolution or other targets.
