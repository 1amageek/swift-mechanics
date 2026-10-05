# Frozen source compilation evidence

## Purpose and Scope
Parent: [system](../../DESIGN.md). Children: none. AF35.18/22/24 own compiler-path evidence for frozen source compositions. This is a verification responsibility, not a production module or feature qualification.

## Responsibilities and Boundaries
Own exact source inventories, generated SwiftPM filelists/outputmaps, driver arguments, diagnostics and compilation/link receipts in project-private .build directories. Production source owners retain causal repairs and behavioral proof. Root owns shared registration, progress and Git.

## Related Designs
| Design | Relationship | Contract Used | Cautions |
|---|---|---|---|
| [System](../../DESIGN.md) | parent | Single public mechanics module and evidence locality | Unqualified source does not become a supplier |
| [XML qualification](../XMLQualification/DESIGN.md) | depends on | Original public XML fixtures and exact profile premises | Target runtime covers XML only |

## Architecture
```text
frozen producer files -> exact private source inventory -> actual compiler diagnostics
 -> causal owner repairs -> stable recompilation receipt
 -> matching SDK compile/link -> unchanged XML guard first, then raw public execution
```

## Contracts and Invariants
No source, declared Sendable/isolation, runtime metadata requirement, physical oracle or original stack reservation may be removed to obtain success. New active sources stay outside a frozen graph. Separate Native and profile snapshots prevent live repairs from changing an in-flight compiler input. Compiler errors remain failures; a diagnostic continuation flag only gathers more failures. No inferred physical or platform support follows from compilation.

## State, Ownership, and Lifecycle
Each private snapshot/cache has one writer. Source and argv inventories are immutable during each process. Live component owners repair their original paths, then hand off a new freeze. Output and historical failure evidence are retained.

## Failure, Concurrency, and Constraints
Pinned Swift6.4.0 release and matching SDKs only. SwiftPM and actual frontend jobs are bounded to four. Each setup has a1200s process-group watchdog. Profiles run sequentially; monitor available disk before each cold profile. Estimated additional artifacts4–10GiB and total10–35min are planning estimates, not measurements. Native follow-up uses a separate snapshot/cache and can progress independently. Actual original131072-byte stack guard executes before unchanged raw WASI only if guard passes; original guarded failures remain failures.

## Verification and Change Impact
Native2178 exact files passed in55.91s with zero errors/warnings, with byte/list identity against current source excluding active foreign formats/JointStops and three older unqualified paths. Receipt: .build/af35-source-compilation/native-compile-receipt.json; inventory SHA256 ed2e8e26dd1dc5369a8178407e682051a3bf10a50d5292bbb28740a6b41c4525. Ordinary/Embedded compile/link and XML subset execution are pending AF35.22; new frozen formats are AF35.24. Full physics behavior, resource scaling, minimum OS, browser, Linux and device backends remain separate proof obligations. A changed source/SDK/driver assumption invalidates only its affected receipt.
