# Nonlinear mechanism verification

Owner: [NonlinearEvolution](../../Sources/SwiftMechanics/Physics/Mechanisms/NonlinearEvolution/DESIGN.md).

| Invariant | Independent behavioral oracle |
|---|---|
| Original nonlinear position/velocity, redundant rows | Cartesian unit-circle norm and q dot v after twenty seconds |
| Original acceleration/reaction | Unit mass centrifugal force and gravity pendulum radial equation |
| Energy | Circle speed and pendulum 0.5 v² + g y |
| Integrator convergence | Analytic sine/cosine solution, squared-error refinement ratio |
| Manifold qdot and bias | Spherical quaternion half-angle spin, 4 q / 3 v, unit norm |
| Atomic accepted state and history | Actual associatedHistory, checkpoint restart exact replay |
| Rejection/initial consistency | Adaptive reject count and inconsistent q/v unchanged Runtime snapshot |
| Supplier failed-work evidence | Late ledger reset/cancel on both success and failure, failed prefix and no publication |

The fixtures compile real spatial bodies and an admitted two-axis translational joint. No diagonal fabricated mass or mock acceleration is used. All tests have explicit time limits. Root owns frozen public Native/WASM/Embedded qualification; local scratch execution does not establish other profiles.

Final local Native snapshot: all 11 tests passed in 14.377 seconds with exact Swift 6.4.0 release, real compiled-tree/rigid mass/Runtime paths, and a 150-second process timeout. The physical witness fixture additionally proves a curved quaternion constraint whose Ndot contribution is nonzero, original J-transpose reaction representatives, moving-row time drift, and cancelled suppliers with known work. The separate reset-success/reset-failure fixtures prove unavailable work is preserved explicitly and no retry/publication occurs. Root owns cross-profile and whole-task integration verification after this source freeze.

Source binding regression owner: NonlinearSourceBindingTests and genuine WrongSourceKernel / WrongSourceMechanismSolver wrappers. The wrappers return actual lower producer results rather than constructing internal records. Different pose/inertia/load inputs and same-time/same-velocity quaternion acceleration snapshots are rejected with specific source mismatch failures and unchanged Runtime state. The two regressions passed in 0.012 seconds; circle20s/replay and quaternion positive paths passed after the repair in 13.762 seconds. These are the targeted recheck of the single comprehensive review finding.

The Embedded-observed lifetime repair was rechecked against all 13 existing Native tests: all passed in 20.709 seconds under a 150-second process timeout using exact Swift 6.4.0 release. Numeric refinement, original reaction/energy/time drift/source binding, supplier cancellation/reset and Runtime rollback/replay remain covered. Root owns actual Embedded stack/runtime qualification after source freeze.
