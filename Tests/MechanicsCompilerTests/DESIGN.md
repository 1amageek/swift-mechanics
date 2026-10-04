# MechanicsCompilerTests

## Purpose and Scope
Behavioral owner of compiler records/capability/validation/revision initial tree domains. Parent: [Compiler](../../Sources/SwiftMechanics/Modeling/Compiler/DESIGN.md).

## Responsibilities and Boundaries
Independent counts/constraint-rank/sparsity oracles, actual tree evaluation and invalid transactional catalog. No physical dynamics/contact/loop execution qualification.

## Related Designs
[Records](../../Sources/SwiftMechanics/Modeling/Compiler/CompilationRecords/DESIGN.md), [Capabilities](../../Sources/SwiftMechanics/Modeling/Compiler/Capabilities/DESIGN.md), [Validation](../../Sources/SwiftMechanics/Modeling/Compiler/Validation/DESIGN.md), [Revisions](../../Sources/SwiftMechanics/Modeling/Compiler/Revisions/DESIGN.md).

## Architecture
```text
bounded descriptor/real generic schema validator -> compile -> actual report/motion or typed failure
old/new models + explicit policy -> invalidation/migrated state or rejection
```

## Contracts and Invariants
Admission authority regression records optional outputs around actual compile and makeState failures; neither invalid coordinate compilation nor actual tree-layout validation publishes a handle. Subsequent valid admission evaluates the actual body motions. Shared-module token constructor access is separately checked by a negative compile probe.

Tests use local immutable fixtures and explicit tolerance/capacity/work budgets. No shared mutable resources; provider tests are actual semantic/dimensional validation, not presence-only checks.

## Verification and Change Impact
Run timeout-wrapped swift test --build-path .build/compiler-kernels --filter MechanicsCompilerTests. Root owns exact Swift6.4 Native/WASM/Embedded composition including generic validator and EmbeddedUnicode trait; unrun profile coverage is explicit.

Native local proof: Apple Swift 6.4 (`swift-6.4-RELEASE`, frontend in `swift-6.4.0-RELEASE.xctoolchain`), timeout-wrapped focused run in `.build/compiler-kernels`: 16 tests across the four compiler suites passed. This evidence covers the fixtures named above only. Ordinary WASM/Embedded compiler composition and generic-validator execution are separately owned by root exact-profile verification. Full MD/PF requirement-family closure remains the later integration obligation.

Additional Native cancellation proof: the targeted `ValidationTests` run passed 6 tests in one suite, including a new Task cancelling itself through `withUnsafeCurrentTask` before actual compilation. The compiler returned the typed `cancelled` input-stage failure through `Result`; no compiled model was published. This adds one fixture to the original 16-test proof without changing production scope. Both runs used the same fixed toolchain, timeout 180 and private build path.

AR01.8 access proof used the exact five token declarations extracted from their issuing files with lightweight immutable payload declarations. Fixed Swift6.4.0 swiftc, thirty-second timeout: same-file token issuance typechecked successfully; an unrelated file attempting all five token initializers failed with five fileprivate-access errors. This proves the token constructor boundary only. Full compiler/session behavioral and target composition verification belongs to the root frozen-snapshot run.
