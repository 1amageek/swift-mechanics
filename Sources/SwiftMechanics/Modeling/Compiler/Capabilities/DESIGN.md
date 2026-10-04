# Capabilities and Extension Validators

## Purpose and Scope
Own feature requirements/manifest and generic required-operation extension validator registration (PF-010 initial compiler contract). Parent: [MechanicsCompiler](../DESIGN.md). No children.

## Responsibilities and Boundaries
Publish exact feature/model/backend/precision/target/evidence metadata and distinguish descriptor validation from qualified execution. Validate extension schemas and dependency evidence through a producer-selected generic provider. Metadata registration never creates force/dynamics/contact/loop solver implementations.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Core](../../../Mathematics/Core/DESIGN.md) | depends on | PhysicalDimension, finite SI values | Scalar parameter units | No implicit unit conversion |
| [Numerics](../../../Mathematics/Numerics/DESIGN.md) | depends on | Float64/reference CPU and NumericalWork/Budget | Exact backend/precision and bounded supplier work | No unknown numerical rank/zero placeholder |
| [Validation](../Validation/DESIGN.md) | used by | Registry and immutable context | Transactional schema admission | Callback is a contract, not execution qualification |

## Architecture
```text
FeatureRequirement -> exact descriptor domain / backend / precision / target check
registered schema -> generic validator(required validate) -> bounded dependency/evidence result
validated descriptors -> manifest: descriptorValidated + scoped producer evidence
```

## Contracts and Invariants
Feature IDs and schemas are nonempty owned strings. Manifest entries carry operation, planar/spatial tree domain, precision, backend, target, owner/evidence revision and qualification state. Built-in compiler feature is descriptor validation of Float64 reference CPU trees; selected target is a requested deployment target, and its execution remains unqualified until root exact-profile integration supplies evidence. Producer evidence f291f24 is explicitly scoped to the already exercised Joints paths, not a new compiler/platform claim. Requests for dynamics/contact/loop/force execution fail even if a provider registers such a declaration. Compiler does not use a Boolean support flag to grant unimplemented physics.

MechanicalExtensionValidating is generic and all invoked operations are protocol requirements, preserving Embedded witness specialization. Registrations uniquely own schema/feature IDs and only descriptorValidation operations in this compiler. Each record carries kind-tagged ID, schema, references and finite dimensioned scalar parameters. Validator receives only immutable descriptor/tree context and a NumericalBudget; it may neither mutate source nor reenter compilation. It must return the same registered feature and bounded NumericalWork plus dependency references; forged feature/dependencies/budget evidence fails. Unknown schemas or missing required parameter/law domains fail explicitly. NoMechanicalExtensions is a complete empty registry that rejects validation calls; it does not validate unknown laws.

## State, Ownership, and Lifecycle
Providers must be immutable Sendable deterministic validation services with no mutation/reentry/external effects. The compiler holds an immutable generic provider and passes no mutable session/callback capability. Supplier internals and budget enforcement remain the supplier's behavioral proof; returned counters are checked cumulatively. Model output owns immutable evidence and parameters. No shared registry mutation or target-dependent conformance.

## Failure, Concurrency, and Constraints
Compiler registration limits, scalar workspace/operations/iterations and diagnostic limits are explicit policy. Call count is bounded by admitted extension records; cumulative supplier work uses NumericalWork absorption. Unsupported execution, duplicate registrations, invalid evidence and validator typed diagnostics abort the transaction. Dynamic heterogeneous dispatch is producer-owned behind the generic provider; no metadata lookup/introspection is used.

## Verification and Change Impact
[Test owner](../../../../../Tests/MechanicsCompilerTests/DESIGN.md) uses an actual bounded dimensional spring-schema validator, invalid law parameters/units, forged evidence/unsupported execution, duplicate schemas and exhausted budget. Native and root exact-profile generic-provider execution qualify only tested validators. IM11/14/20/26/35 owners can supply new validators using this contract; their physical execution remains independently qualified.
