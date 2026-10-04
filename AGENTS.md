# Repository Instructions

## Scope and authority

Apply these instructions to work in this repository together with applicable parent instructions and the user's current request. Keep task scope explicit. Investigation and review do not authorize unrelated source changes. Preserve concurrent work and resolve consequential conflicts before editing affected paths.

All repository code, comments and documentation must be written in English. Follow the user's preferred language for conversation.

| Authority | Owned decisions |
|---|---|
| [SPEC.md](SPEC.md) | Requirements, domains, failure semantics and acceptance conditions |
| [DESIGN.md](DESIGN.md) and child designs | Architecture, component contracts, invariants and ownership |
| [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) | Stable work IDs, prerequisite edges, requirement ownership and handoffs |
| [PROGRESS.md](PROGRESS.md) | Current authorized work, readiness and completion evidence |
| [PHILOSOPHY.md](PHILOSOPHY.md) | Design principles |
| [README.md](README.md) | User-facing introduction and qualified capability descriptions |

Keep each decision in its owning document and link to it elsewhere. A planned requirement, declaration or successful build is not implementation evidence.

## Understand the actual path

Before proposing or changing a contract, read its concrete implementation, callers, relevant tests and design. Use `rg` for targeted searches and `skltn` as a structural entry point when available; inspect original source before drawing conclusions.

Trace admission, selected branches, equations, state ownership, publication and failure behavior. Distinguish verified current facts, target behavior, required changes and unresolved decisions. Do not infer complete behavior from names, types or a single call site.

## Architecture and design

- Keep one public mechanics module, `SwiftMechanics`, unless an authorized design change establishes a necessary boundary.
- Place production responsibilities in their owned component directories and maintain their `DESIGN.md` contracts before changing public behavior.
- Use native SwiftPM package and target boundaries. Separate CAD, foreign engine and environment-specific dependencies through adapters as defined by the system design.
- Define public operations through focused protocols with separate implementations and typed failures.
- Consume other components' published contracts. Admission tokens, immutable records and internal visibility do not grant another component's authority.
- Keep geometry authority in the CAD provider and mechanical interpretation in mechanics.
- Recheck dependent assumptions when a supplier contract changes; retain valid evidence whose premises are unchanged.

## Physical and numerical correctness

- Follow the specification's units, frames, coordinate conventions and force-versus-impulse semantics.
- Preserve distinctions between prescribed motion, load-driven dynamics, contact laws and flexible constitutive models.
- Accept results through the original physical or numerical checks, not merely an iteration flag.
- Preserve original equations, operation-specific accounting and physical residuals during performance or lifetime repairs.
- Represent unsupported domains, invalid inputs, nonconvergence, cancellation and resource limits as explicit failures.
- Make any approximation policy explicit and attributable. Do not silently substitute a model, precision, backend or default value.
- Limit capability claims to the exact verified model, operation, domain and execution profile.

## State, concurrency and resources

- Preserve accepted-state identity, atomic publication, rollback, checkpoint provenance and exactly-once resource release.
- Keep mutable state under its documented owner and isolation boundary. Use `Mutex` for short synchronous memory access or actors for suspension and ordered asynchronous lifecycles.
- Maintain the same synchronization and `Sendable` contracts across Native, WASM and Embedded. Embedded compilation does not imply single-threaded execution.
- Give borrowed storage explicit owner and lifetime contracts. Reduce repeated allocations and copies when justified by the workload and measurement.
- Define bounded work and storage with explicit exhaustion behavior. Investigate stack and temporary lifetimes using the actual target path.
- An increased stack, weakened acceptance check or silent fallback is not evidence that the original contract now works.
- Place an English `// FIXME(INCOMPLETE_IMPLEMENTATION):` comment immediately before any callable incomplete implementation. Record what is incomplete, the current production call path and the conditions required before success can be claimed. Return an explicit failure rather than placeholder success. Remove the marker only with behavioral evidence for the completed path.

## Work coordination

For a task with multiple work items, the integration owner maintains the repository's single `PROGRESS.md`. Other owners report evidence to that owner rather than competing to edit the record. Keep it as `# Progress` followed by Markdown task lists. Each executable item has a stable unique ID, an outcome, `depends:<IDs|none>` and `parallel:<group|none>`; child IDs include the parent ID. Place prerequisites before consumers and the whole-task integration item last. An item is ready only when its dependencies are complete. Parallel groups contain only independent sibling leaf items with safe shared-state and verification premises. Mark completion only after the item's required verification, review and coding commit; parents also require all children. Preserve completed IDs and commit references, and reopen an item only when its completion evidence is invalidated.

Start production work only after the required supplier handoffs have behavioral evidence. Parallel workers need non-overlapping implementation and test paths, explicit contract ownership and compatible verification premises. Shared manifests, public contracts, verification entry points and mutable fixtures have a single writer.

Do not revert another contributor's edits or claim their unfinished work. Freeze relevant sources before integration qualification. Keep independent findings outside the current task unless the user changes scope.

## Verification

Verify at the scope that owns the invariant. Use independent physical oracles and meaningful success, failure, boundary, rollback and lifecycle cases as applicable. Type checks, mocks and constant-return implementations cannot certify production behavior.

Run focused Native tests through [Scripts/run_with_timeout.py](Scripts/run_with_timeout.py) with the pinned Swift 6.4.0 toolchain. Ordinary and Embedded WASM require matching SDKs, separate build paths, compile/link and actual runtime execution. [Verification designs](Verification/FoundationVerification/DESIGN.md) own exact profiles and evidence. Platform declarations are not runtime qualification.

Use `xcodebuild test` on the actual Apple path when a change uses Metal; pure logic can use `swift test`. Every test command needs a timeout. Run affected checks after a stable source boundary and whole-task integration after the component obligations close. Reuse evidence only while its source and assumptions remain valid.

For documentation-only work, check factual claims against authoritative records, local links, image assets, code snippets and Markdown structure. Do not run unrelated physics suites to qualify prose changes.

## Completion and Git

Complete each coherent sprint with its required review and verification, then a local commit. Confirm the branch and commit message first. Stage only owned files by explicit path and preserve unrelated staged or working changes. Commit messages describe the change in English without promotional or AI attribution footers.

After task integration, use a normal push to the current branch's configured upstream when authorized and all included commits belong to the task. If other tasks' unpushed commits are present, do not upload them implicitly. Force pushes, history rewrites, new remote destinations, tags, releases and deployment require the applicable explicit authorization.

Commit at verified work boundaries. Scheduled polling and unattended commit automation are not part of this repository's workflow unless the user explicitly requests them.

Report what changed, the evidence obtained and remaining limitations. Do not call a feature complete while its relevant contract or actual execution path remains unverified.
