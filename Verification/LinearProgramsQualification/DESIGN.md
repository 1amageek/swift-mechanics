# Linear programs selected qualification

## Purpose and Scope
Parent: [system](../../DESIGN.md). No children. Root owns independent qualification of [LinearPrograms](../../Sources/SwiftMechanics/Analysis/Optimization/LinearPrograms/DESIGN.md). The source implementation is frozen; other source owners continue independently.

## Responsibilities and Boundaries
Own original-data optimal, infeasible, unbounded, redundant/degenerate and failure fixtures. Source availability, tableau flags and type checks do not prove LP meaning. No QP/nonlinear or complete OP004 claim.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [LinearPrograms](../../Sources/SwiftMechanics/Analysis/Optimization/LinearPrograms/DESIGN.md) | depends on | Public protocol and original certificates | Preserve original source and tolerances |
| [SourceCompilation](../SourceCompilation/DESIGN.md) | coordinates with | Frozen compiler provenance | Aggregate compile is not behavioral proof |

## Architecture
```text
independently authored original rows/bounds/SI scales
 -> public solver -> original row/dual/ray recomputation
 -> Native tests and selected Native/WASM/Embedded public execution
```

## Contracts and Invariants
Known objectives and physical scaling must match independent arithmetic. Original feasibility, nonnegative inequality multipliers, stationarity, complementarity and gap are recomputed. Farkas weights must give zero normal and strictly negative RHS in unrestricted fixtures. Recession paths must preserve equality/inequality/bound signs for arbitrary positive travel. Resource/cancel/nonfinite/tiny-pivot failures retain problem provenance and consumed work.

## State, Ownership, and Lifecycle
All fixtures are immutable or call-local; no shared mutable state. Freeze exact production and fixture source bytes before actual compiler/test execution. One root writer owns private package/cache and registration.

## Failure, Concurrency, and Constraints
Pinned Swift6.4.0 release and matching SDK only. Setup timeout600s, tests60s and public runtime120s. Use actual job/thread4 bounds. Original131072 stack-write guard must pass before each raw WASM execution. No stack increase, solver tolerance weakening, source dropping or hidden fallback.

## Verification and Change Impact
Fixtures and exact evidence will be recorded here after execution. Changed physical/source/SI premises invalidate affected evidence; unchanged supplier evidence is reused. Selected qualification may progressively register/commit without waiting for other implementations.


## Selected qualification evidence
Frozen117 producer files and all four fixture Swift files remained byte-identical through Native, ordinary and Embedded execution. Native setup28.63s, six tests and all six public witness groups passed. The canonical registered production composition at e89c29d (including the separate environmental-load merge) plus LP built86.43s and the same six tests passed. No unrelated full-suite claim follows. Original equations independently verified analytic bounded/free/fixed/redundant optima, SI point/objective/dual scaling, original KKT/gap, unrestricted Farkas contradiction, exact equality-null/zero-row recession, a degenerate Bland fixture and typed budget/cancellation/tiny-pivot/nonfinite failures with provenance/work.

Ordinary matching release SDK setup17.65s and Embedded setup13.71s compiled/linked. Original131072-byte immediate stack-write guards covered every decoded stack write (ordinary19868, Embedded483); guard executed before each raw artifact and all six unchanged public witness groups passed both. Node24.19.0 WASI Preview1 only; no browser/threading/Linux/iOS/minimum-OS or full210 proof. All public operations were called through the original protocol.

Exact source/object/tool/argv/artifact/log provenance: `.build/af35-linear-programs-qualification/selected-qualified-provenance.json`, SHA256 77c6bf25d210ad7f64bd0ebd0d95b2d3df72e54aed307b88043a97f8b8fe58b5. Native initial scratch output is `/Users/1amageek/Desktop/3D/native`; later profile/canonical paths are absolute project-private paths as recorded. Native actual driver jobs4; ordinary batch-mode warns that num-threads is ignored, with no frontend thread flag; Embedded actual WMO frontend threads4. Documented native build backend deprecation and canonical dSYM debug-prefix module-cache warnings are preserved, without source errors or oracle changes. Source review confirms only call-local mutable tableau/arrays plus caller inout work; public inputs/results immutable Sendable on all targets, no unsafe/shared/isolation-conditional storage.

Registration retains one public SwiftMechanics module and one focused canonical test target co-locating Cases/Error/Tests while excluding the standalone entry point. A changed registered source/manifest assumption invalidates only its affected proof. The large2178-source Embedded conformance assertion remains a separate open composition gap.
