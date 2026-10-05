# Environmental load contract tests

Each named suite owns the same-named load child contract. Independent hand-computed cap/polar/traction/gravity fixtures, derivative differences, rotation covariance and explicit domain/resource/cancel failures execute real public protocol dispatch. No shared mutable fixtures. SideLoadIntegrationTests owns cross-law force/work composition, not the whole 210-requirement plan. Native baseline only; other profiles remain unverified.

## Native evidence (2026-10-05)

Pinned toolchain: `/Users/1amageek/Library/Developer/Toolchains/swift-6.4.0-RELEASE.xctoolchain/usr/bin/swift` (Apple Swift 6.4, swift-6.4-RELEASE). Host: macOS 27.0.1 arm64. The actual root SwiftMechanics module includes all five new production components and this registered target. The generated target file list includes all six suite files and the shared immutable fixture. No isolated substitute implementation is used.

Build: `python3 Scripts/run_with_timeout.py 1200 <swift> build --build-path .build/side-five-swiftbuild --build-tests -j 2`, exit 0. An initial Native build-system attempt exposed a filename/type collision with the existing one-dimensional transmission drag law; the new law was named HydrodynamicDrag and built with the default Swift Build system. Initial test compilation exposed missing try in assertions, corrected without production changes. A cumulative build then succeeded in 101.89 seconds using the existing cold-build products.

Behavior: `python3 Scripts/run_with_timeout.py 60 <swift> test --build-path .build/side-five-swiftbuild --skip-build --disable-xctest --enable-swift-testing --filter 'SphereHydrostaticsTests|DirectionalHydrodynamicsTests|AerodynamicPolarsTests|FollowerPressureTests|HarmonicGravityTests|SideLoadIntegrationTests' -j 2`, exit 0; 15 tests in six suites passed. The first identical test invocation timed out before any output after 60 seconds. A diagnostic invocation subsequently executed all tests successfully; process sampling timed out and did not establish the startup cause. This record does not certify SwiftPM startup reliability.

Private evidence is retained in `.build/side-five-evidence/` (build/repair/test/diagnostic logs and source SHA-256 inventory). Synchronous evaluation behavior only is qualified; minimum macOS13, browser, iOS, Linux, ordinary WASM, Embedded and performance are unverified. No Metal/GPU or foreign engine is used. Existing cancellation-ledger behavior is exercised by all five public evaluators; no asynchronous lifecycle claim follows.

| Suite | Original proof |
|---|---|
| SphereHydrostaticsTests | Independent hemisphere/full/dry cap values, potential/force derivatives, frame covariance, work/capacity/cancel |
| DirectionalHydrodynamicsTests | Axial/transverse coefficients, all Jacobian columns, rest derivative, medium work, rotation/envelope |
| AerodynamicPolarsTests | Independent table interpolation and angled lift/drag, rotated frame, relative/medium work, no extrapolation/crossflow |
| FollowerPressureTests | Original nodal/resultant force/moment/power, all nine directional derivatives, rigid-translation kernel, degeneracy |
| HarmonicGravityTests | Original force/potential/time derivative, every spatial derivative, total potential rate, invalid symmetry and overflow |
| SideLoadIntegrationTests | Five actual public protocol paths, common frame/body/resultant, rigid transform covariance, all five cumulative failure contracts |
