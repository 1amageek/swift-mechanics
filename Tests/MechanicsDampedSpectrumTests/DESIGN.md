# General damped spectrum evidence

## Purpose and Scope
Focused tests of [GeneralDampedSpectrum](../../Sources/SwiftMechanics/Analysis/StructuralAnalysis/GeneralDampedSpectrum/DESIGN.md); no children.
## Responsibilities and Boundaries
Independent physical roots/modes/refinement/failures; root owns public profiles.
## Related Designs
Production child owns quadratic contract; ComplexSpectrum owns lower computation.
## Architecture
```text
analytic physical pencil -> actual service -> original complex equation/mass norm
```
## Contracts and Invariants
Expected roots come from explicit physical factors/determinant, never output.
## Verification and Change Impact
Focused Native plus affected legacy structural/numerical suites.

## State, Ownership, and Lifecycle
The cancellation-only test counter and late-cancellation flag has identical storage and access source for all targets. No callback/I/O/await occurs inside its lock; separate instances avoid cross-test state. Native tests execute cancellation, not WASI parallel races.

| State | Native | WASM | Embedded |
|---|---|---|---|
| Storage/isolation | immutable Mutex<Int>/Mutex<Bool> owners | same source | same source |
| Read/mutation | cancelled() through withLock, saturating count | same source | same source |
| Release | caller releases owner after operation | same source | same source |
