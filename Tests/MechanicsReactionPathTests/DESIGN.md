# Reaction path behavioral evidence

Owner: [ReactionPaths](../../Sources/SwiftMechanics/Physics/Mechanisms/ReactionPaths/DESIGN.md). Public TreeReactionRecovering executes original Dynamics Newton/Euler and actual Loads/Joints paths.

| Oracle | Body/load owner | Rejected counterexample |
|---|---|---|
| Pendulum analytic F=m*(alpha cross r + omega cross omega cross r)-m*g and T=I*alpha+r cross F | Child body only for hinge; fixed root's independent weight included only in root support | Generalized torque labeled as six-axis support; doubled root weight |
| Vertical static two-link subtree force and offset transverse-load moment | Distinct first/second masses and physical force point | Only child-body balance instead of whole subtree; missing moment shift |
| Rotated frame and translated joint anchor | Actual public snapshot poses and same world reference for both signs | Rotation-only torque or inconsistent action/reaction reference |
| Floating body original free dynamics | Whole free tree; no support owner | Invented support hiding acceleration error |
| Failed paths and ledgers | Caller limits/cancellation; immutable suppliers | Report after ambiguous loads, wrong acceleration, exhausted resources or erased work; zero/precharged callback prefix with reset on both success/failure; original cancellation closure retained |

Native focused tests have deadlines through Scripts/run_with_timeout.py; root owns frozen-source registration and Native/WASM/Embedded public probes. Test fixture is owned independently here; no production source uses it. All mutable test data is local. Injected suppliers deliberately replace ledgers; they are failure oracles, never accepted physical producers.
