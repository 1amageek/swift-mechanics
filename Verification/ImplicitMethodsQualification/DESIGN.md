# ImplicitMethods Qualification

## Purpose and Scope
Parent: [ImplicitMethods](../../Sources/SwiftMechanics/Execution/Integration/ImplicitMethods/DESIGN.md). No children. Own independent behavioral qualification of the original31 source backward Euler Runtime transaction and generalized-alpha/HHT endpoint equations. Selected original8 Native tests and7 public cases have source-bound evidence; historical preparation alone is not behavior evidence. Structural proposals are not Runtime publications. No new integration method, nonlinear stability theorem or broader TI-003 completion claim is introduced.

## Responsibilities and Boundaries
Build an actual compiler-admitted one-prismatic physical model and a declared mass/spring/damper/constant-load provider through public protocols. Providers own that physical balance and exact tangent; the real original nonlinear solver owns Newton iterations and original-residual acceptance. Euler uses the actual original RuntimeSession and checkpoint handler, never a manufactured accepted-state token. Independent closed-form and bisection oracles own expected endpoints, physical residuals, energy and convergence order. Fault modes deliberately violate one provider contract at a time and must produce typed refusal and unchanged accepted data. Root owns shared registration, source graph, Package, parent documents, progress and Git.

## Related Designs
| Design | Relationship | Contract used | Cautions |
|---|---|---|---|
| [ImplicitMethods](../../Sources/SwiftMechanics/Execution/Integration/ImplicitMethods/DESIGN.md) | parent / verifies | Euler step and structural endpoint public protocols | Preserve explicit Euclidean/constant-mass domains |
| [Equations](../../Sources/SwiftMechanics/Execution/Integration/Equations/DESIGN.md) | depends on | Descriptor, chart read/prepare/derivative/write and physical SI dimensions | Fixture equation is caller-owned physical law |
| [Runtime](../../Sources/SwiftMechanics/Execution/Runtime/DESIGN.md) | depends on | Actual trial, publication, cancellation and rollback | Use committed d30b585 implementation only; live AF31 is excluded |
| [Nonlinear](../../Sources/SwiftMechanics/Mathematics/Nonlinear/NonlinearSolve/DESIGN.md) | depends on | Real solver and original residual, exact tangent directional validation | Unknown failed supplier work stays unavailable |

## Architecture
```text
original31 SHA + committed d30b585 suppliers -> matching common producer -> direct read-only module/dylib
actual body/inertia/joint -> real mechanical compiler -> model stamp
    -> public physical ODE provider -> real Euler -> exclusive Runtime trial -> accepted checkpoint
    -> public structural balance/tangent -> real generalized-alpha or HHT -> endpoint proposal
independent physical formulas -> original residual / endpoint / energy / order comparison
provider fault or budget/cancel -> typed failure -> accepted state/random/contributor unchanged
```

## Contracts and Invariants
The primary physical law is mass2kg, stiffness8N/m, damping0.6N*s/m, constant load1.2N; nonlinear Euler/structural force adds3N/m^3*q^3. q0=0.25m and v0=-0.2m/s. Initial acceleration equals the original physical balance. Backward Euler linear endpoint has v1=(m*v0+h*(F-k*q0))/(m+c*h+k*h*h), q1=q0+h*v1, a1=(F-k*q1-c*v1)/m. Its nonlinear Euler witness independently bisects the strictly monotone physical equation in v1 for120 iterations, starting from[-100,100], with q1=q0+h*v1. Check the independent physical residual, chart/time/model identity, public endpoint derivative and accepted acceleration. Energy is measured relative to static equilibrium F/k; Euler must satisfy the exact discrete identity E1-E0=-h*c*v1^2-m*(v1-v0)^2/2-k*(q1-q0)^2/2. Endpoint and physical residual comparisons use2e-10 absolute plus2e-10 relative.

Structural linear endpoints are solved independently from the scalar coefficient of a1 in the public Newmark and weighted physical balance definitions. Nonlinear HHT uses a separate120-iteration monotone bisection of actual old/new endpoint balances, never a weighted-state substitute. Compare original force balance and show the distinct wrong weighted-state nonlinear expression is nonzero. Generalized-alpha rho=1,0.5,0 and HHT alpha=0,-0.2,-1/3 retain original parameter values, scales and exact input equilibrium. HHT alpha0 checks nondissipative trapezoidal energy for an undamped unforced oscillator. Linear Euler order uses successively20,40,80 steps to1s from q=1,v=0 with m=k=1 and independent Taylor point sin/cos oracle; expected first-order error ratios lie in[1.8,2.2]. This is a point/reference check, not a uniform transcendental enclosure claim.

Prepare increments one real contributor byte and the actual trial random sequence. Success publishes both once; malformed derivative/write/preparation, cancelled work, wrong tangent, replaced numerical ledger and unavailable supplier failure must preserve the complete prior accepted checkpoint, including both fields. Repeating a healthy step after rollback must agree with a fresh session and publish only one preparation increment. Unsupported domains, stale descriptor, integrator continuation category, time/layout/scales and all finite work capacities remain explicit failures.

| Public case | Independent witness |
|---|---|
| Euler physical endpoint/energy | Closed form, actual publication, original SI residual |
| Euler convergence/repeat | Point solution, order ratio, fresh-session equality |
| Generalized-alpha endpoints | Independent coefficient solve at three rho values |
| HHT nonlinear/endpoints | Original two-endpoint balance vs independent bisection; alpha0 energy |
| Provider refusal/rollback | Fault-specific typed failure, unchanged accepted random/contributor/state |
| Domain/owner admission | Unsupported/stale/chart/time/integrator and busy owner branches |
| Budget/cancellation | Numerical/Runtime work limits, callback cancellation and recovery |
| Native Task cancellation | Prepared immutable input; cancel then await actual task, no publication |

## Runtime Flows
Read source/public providers and freeze fixtures first. No compiler, link or runtime starts before the matching committed d30b585 common-producer handoff and root Native reader grant. Thin setup uses fixed6.4.0 release, Native SwiftPM/jobs4, joined import arguments and direct read-only module/dylib. Setup deadline300s, tests60s and public120s apply to process groups. Preserve the first failure; fixture API diagnostics are local. A physical source counterexample requires a design-first causal correction and coherent matching module/object producer before reexecution. No ABI/object mixing or lower-provider edits.

## State, Ownership, and Lifecycle
Each case owns immutable physical coefficients/model/descriptor/policy and exclusive step-local numerical ledgers. Runtime owns accepted state and exclusive trial storage; fixture callbacks use its public mutation APIs only. Callback hooks are immutable Sendable closures and execute outside fixture locks. No shared static mutable state, unchecked Sendable or target-dependent isolation is used. Inputs, proposals and failure records remain immutable values. Every created session is explicitly shut down after its witness.

| State | Native / ordinary / Embedded owner | Isolation | Read / mutation | Release |
|---|---|---|---|---|
| Accepted/trial | Same original RuntimeSession | Original Mutex/ticket contract | snapshot / public trial APIs | shutdown after case |
| Coefficients and descriptor | Immutable fixture values | Sendable immutable | Public provider reads | Case lifetime |
| Numerical work | Exclusive local NumericalWork | Exclusive inout | Provider charge / method composition | Step return |

## Failure, Concurrency, and Constraints
AF42 thin Native consumer cumulative additional1GiB, growth stop896MiB; global free floor4GiB, stop4GiB+128MiB, admission4GiB+128MiB. Sample2s with maximum5s observation; one baseline persists across causal corrections. Compiler/runtime commands always have process-group deadlines. Fixed fixture numerical budget200000 operations,4096 scalars,256 iterations; Runtime trial work10000 units and safe-point quantum4. Failure tests lower one original budget and preserve known work; unavailable supplier consumption is explicitly asserted rather than invented. All common public cases are synchronous; awaited Task cancellation is Native-only evidence.

## Verification and Change Impact
Historical preparation status: no compiler or behavior evidence. Original31 live Swift sources matched frozen2363 source hashes at that preparation. Its old depot and private records are unavailable after the root capacity recovery; none are reused by AF42. The current live RuntimeSession and ReferenceRuntimeCheckpointHandler differ from those original sources; the fixture must use the immutable2363 source/object/module premise and may not qualify current AF31 work. [Source freeze2](../../.build/af35-implicit-methods-qualification/fixture-source-freeze-2.json), SHA256 `be89045bff1fe107b1c631d30c1efe2ddcbf526bb563c554dafc1a5ac8bb902b`, binds original31, eleven fixture Swift files, all2363 readonly objects and3 module metadata, and the45 original Runtime source paths. [Native preparation receipt](../../.build/af35-implicit-methods-qualification/native-preparation-receipt.json), SHA256 `c2eaab55c491b716ea49d0870437666e242ff52c93f03721cdc8ab386e2896f4`, records the pending root lease and enforced operational gates. Earlier unexecuted preparation is retained. No concrete production counterexample was found in the scoped source path; this observation is not a behavioral success claim. Exact source/object/library/fixture/link/after-runtime receipts are required for later Native evidence. Physical coefficients, weighting/tangent/scales, Runtime admission/publication, original nonlinear supplier and budgets invalidate affected witnesses when changed. Portable profiles require a separate root lease and actual target execution.

### AF42 committed-supplier continuation
The old2363 depot is unavailable. AF42 replaces only that unexecuted supplier premise with a matching fresh common producer from committed d30b585 Runtime. All31 owned production Swift files are frozen without changes. Original physical coefficients, equations, tolerances, budgets,8 Native tests and7 public cases stay fixed. The consumer is additional1GiB/global free4GiB with2s sampling/5s observation watchdog, Native6.4.0 release/jobs4 and300s setup deadline; all runtime commands also have deadlines. Root alone grants the reader slot after coherent module/object/library handoff. No compiler or runtime evidence is claimed at preparation.

The actual compiler initial-assembly path requires the moving body's stored reference pose to equal its initial prismatic coordinate. The original fixture declares identity while initial q=0.25m. Set that body's reference translation to(0.25,0,0) while preserving initial q/v, all anchors/axes, physics and independent numerical oracles. Original fixture bytes are retained in the owned private qualification directory. Testing14 invokes the existing15-only Runtime helpers through body availability guards with explicit typed unsupported-platform refusal; the suite itself remains unannotated, as required by actual Swift Testing macro capability. Public deployment13 uses the same typed refusal. This is capability dispatch and input assembly consistency, not method or tolerance change.

### Actual fixture compiler correction
The first AF42 thin setup stopped at `ImplicitMethodsQualificationFixtures.swift:32`: the local identifier helper declared CoreError while the actual committed EntityID initializer throws ModelError. No test or public case executed. Preserve the original setup log/receipt and fixture freeze. The helper now declares the supplier's actual ModelError; the existing typed translation retains that case. No cast, error suppression, source31, physical oracle, tolerance or budget changes follow. Reexecute only the corrected thin consumer with the same immutable2387 module/dylib and one cumulative storage baseline.

### Actual fixture identity correction
Attempt2 compiled successfully and executed all8 tests; four failed before Euler numerical execution because the fixture ODE validator assumed descriptor body index1 was the moving body. The actual compiler canonicalizes descriptor records by identity, placing the fixed1kg body at that index; the intended moving2kg inertia is elsewhere. Equal-mass oscillator witnesses passed, exposing why index coincidence cannot establish authority. Resolve the moving body using the actual sole tree joint childBody ID and find that original descriptor record; keep spatial/prismatic/mass equality admission unchanged. This corrects the fixture's source-to-physics mapping without changing implicit production31, masses, initial state, oracles, tolerances or budgets. Preserve failed test/receipt/source copies and use the same immutable2387 producer for the affected original8/public7 continuation.

### AF42 selected Native evidence
The matching common producer was freshly compiled from committed d30b5852270 plus117 frozen feature sources, including the unchanged31 ImplicitMethods files. Its immutable2387-source/object/module/dylib composition is consumed directly. The two failed thin attempts remain retained: the first stopped at the fixture identifier error declaration; the second executed8 tests and found the fixture's descriptor-index identity error. The final attempt corrects those fixture paths, preserving original equations, SI values, independent oracle expressions, tolerance, budget and test/public counts.

| Evidence | Exact binding |
|---|---|
| Common producer | `.build/af42-next-native/attempt-2/handoff.json`, SHA256 `f6c4959f204ce51cb07259224891546bd4d18847d397d9a6731d68095ae77941` |
| Production31 | `.build/af42-implicit/production-source-freeze.json`, SHA256 `6845575afd1c62c2d81606bbdfeaa199bfc9a4891ee5c10d4f7f72d1c072b2c9`; no source delta |
| Final fixture11 | `.build/af42-implicit/fixture-source-freeze-attempt-3.json`, SHA256 `78d4580b83919e96baa56c42cf09e65eeacfde2cef34aae6bcd109d1280d3d5b` |
| Selected runtime | `.build/af42-implicit/native-receipt-attempt-3.json`, SHA256 `9f2a92e7d04ec64895f4da3dc26f63dfdbb40ef42d6bfc960bc22dbaf8647af8` |
| Setup / tests / public |26.291s /2.043s /2.026s wall time, exit0; Swift Testing8/8 reported0.023s, direct original7 public cases with exact literal stdout |
| Source/object/link | Whole2387 source/object identities,3 metadata files and dylib verified read-only before/after; owned31/11 source, actual emitted11 consumer source/object bindings, consumer metadata and executable verified before/after; actual dylib dependency inspected |
| Direct lower authority | `.build/af42-implicit/required-committed-lower-inputs.json`, SHA256 `c743a05a3178d7d6b57c9cd2d2b24830a517cc0c98d8251200f9cc3a79f86f85`;195 committed component inputs include45 Runtime files; other transitive baseline inputs retained by the whole producer |
| Operational bounds | Swift6.4.0 release/MacOSX27.0 SDK, Native engine and actual jobs4, support/public13 and Testing14 with helper15 bodyguards; setup300s/tests60s/public120s,2s sampler/5s observation watchdog, one cumulative baseline across failures, final private growth130,420,736 bytes below1GiB;4GiB global free floor preserved |

All fixed original8 Native and7 public witnesses passed. They establish the declared physical providers and Runtime paths, not general provider correctness, a nonlinear stability theorem, uniform transcendental enclosure, arbitrary interleavings, full TI-003 completion or ordinary/Embedded behavior. Native-engine deprecation warnings, failed receipts/logs/source copies and first runtime failure's full producer post-binding remain retained. No Core recompile or object copy occurred in the consumer. The reader slot is released; shared registration is root-owned and must rebase the separate minimal additive candidate.
