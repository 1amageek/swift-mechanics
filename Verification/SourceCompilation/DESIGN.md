# Frozen source compilation evidence

## Purpose and Scope
Parent: [system](../../DESIGN.md). Children: none. AF35.18/22/24/31 own compiler-path evidence for frozen source compositions. This is a verification responsibility, not a production module or feature qualification.

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
Pinned Swift6.4.0 release and matching SDKs only. The execution contract bounds actual driver jobs and WMO frontend threads to four. SwiftBuild was observed appending a later -j14 and generating -num-threads14 despite forwarded flags; an early -j4 is not resource evidence. Planning-only regeneration may use the pinned driver-supported -driver-print-jobs, then the exact generated argv is replayed with only planning removal, diagnostic continuation and effective job/thread bounds. Record the original and corrected argv explicitly. Each setup has a1200s process-group watchdog. Profiles run sequentially; monitor available disk before each cold profile. Estimated additional artifacts4–10GiB and total10–35min are planning estimates, not measurements. Native follow-up uses a separate snapshot/cache and can progress independently. Actual original131072-byte stack guard executes before unchanged raw WASI only if guard passes; original guarded failures remain failures.

## Verification and Change Impact
Native2178 exact files passed in55.91s with zero errors/warnings, with byte/list identity against current source excluding active foreign formats/JointStops and three older unqualified paths. Receipt: .build/af35-source-compilation/native-compile-receipt.json; inventory SHA256 ed2e8e26dd1dc5369a8178407e682051a3bf10a50d5292bbb28740a6b41c4525. Native2216 with frozen SDF17/OpenUSD21 also passed; its first SwiftPM job bound was not proved, while the exact driver -j4 replay passed with byte/object correspondence (native-compile-receipt-pass-7.json, inventory c065f7cab1df46b3f8327f12e55cc780e7e8e6cfc5fd702ce933a3d47e7ed1ca). Ordinary2178 compile/link passed149.64s; original decoded45497 stack writes all guarded at131072 bytes, guard then unchanged XML raw both exited zero. Embedded failed in mandatory witness/default-method specialization at Conformance.swift:62 twice; no link/runtime proof exists. Forwarded thread correction was not applied in the second actual argv. Exact profile result and diagnostic failures are .build/af35-fixed-profiles/fixed-profile-result.json. Native2262 with MJCF31/JointStops15 passed after planning-only argv regeneration and final driver4, all2262 objects bound (native-compile-receipt-pass-8.json; inventoryf9c702626c9d814f2edc8ce37f497c11fa4583635489a0c745885d3f9746106c). The producer cache is frozen/read-only for immutable object/module reuse by independent qualification owners. One actual frontend-thread4 Embedded diagnostic still failed the same assertion; supported current-function diagnostics yielded no source attribution. Causal Embedded diagnosis remains open. Full physics behavior, resource scaling, minimum OS, browser, Linux and device backends remain separate proof obligations. A changed source/SDK/driver assumption invalidates only its affected receipt.

### AF35.31 frozen continuation
Native2339 and2353 passed with exact source/object inventories and final driver4. Pass10 includes Heightfields22, Hydroelastic17, AssetResolution18, WheeledAssemblies14 and the separately committed environmental20; module SHA75c5fcac39cd4900d2fc66d95900784027f6b30f42f3f2d343396af9133e936c. SDF/OpenUSD consumers each copied and verified every2353 object and three module-metadata files before the producer cache was reopened. Their actual Native behavioral proof belongs to their own qualification owners.

Pass11 adds only frozen CompoundQueries10, for2363 source files. Exact immutable source inventory80eb84d7d62cc30138b0c9fe705c5f73e4777024eb64e8f371f8477bd6b86aa3 compiled with zero diagnostics, driver4 and all2363 objects. Receipt native-compile-receipt-pass-11.json, output ledger native-output-inventory-pass-11.json and module SHA689c2037c5dc386fc2f19188202b892c04e7eada9b3428248f66bb1dbef1b85f retain the actual compiler binding. `exactRootMatch` is explicitly false: concurrent authorized AF31 repair changed only live `PhysicalRigidDynamicsSystem.swift` after its frozen9bc5da1d4bef1e3f7ec800ee1629dd70631b95bf0d198f09b556de50d0f75b7e snapshot. This receipt qualifies only the frozen compiler input, not the current live supplier or feature behavior. No new supplier was silently copied or implicitly qualified.

### Resource-preserving completed-cache archive
The completed root-owned XML canonical cache was archived to `.build/af35-xml-canonical-cache.tar.gz` (SHA57cd83f2a0f978de06b636eb79d46f9da3c7150e7ff1e0c7f7824ffc25cd3b24). Every21686 file/directory/symlink entry and original regular-file byte SHA was verified by reading the archive before removing only that completed cache directory. Original inventory and archive receipt remain in .build; source, logs, proof receipts and runnable bytes are preserved and recoverable. This frees1.45GiB without changing an active snapshot or oracle. Actual archiving191.55s; concurrent large LLVM decodes exceeded120/240s deadlines and remain incomplete, so subsequent full decoding is sequential with an observed-progress600s watchdog. No failed decoder is reported as complete stack-write coverage.
