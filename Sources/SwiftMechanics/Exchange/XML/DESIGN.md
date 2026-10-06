# Bounded XML interchange syntax

## Purpose and Scope
Parent: [Exchange](../DESIGN.md). Children: none. AF34.2 supplies the markup prerequisite for IO-003..006 without claiming any foreign mechanics semantic adapter. The normative syntax reference is [XML 1.0 Fifth Edition, 26 November 2008](https://www.w3.org/TR/2008/REC-xml-20081126/). This is an explicitly restricted interchange subset, not a conforming general XML processor.

## Responsibilities and Boundaries
Own byte syntax, immutable document records, budgets and transactional parse/write. Foreign adapters own schema/version selection, numerical interpretation, required fields, units, losses and asset admission. No FoundationXML, file, network, DTD resolution, global cache or target-specific storage.

## Related Designs
| Design | Relationship | Contract Used | Summary | Cautions |
|---|---|---|---|---|
| [Exchange](../DESIGN.md) | parent | Explicit bounded exchange failure | Generic syntax prerequisite | Qualified restricted subset; see verification owner |
| [Schema](../Schema/DESIGN.md) | coordinates with | Immutable values and logical-budget convention | XML has independent syntax policy/errors | Does not create SMNX model records |
| [Core](../../Mathematics/Core/DESIGN.md) | coordinates with | Common Sendable/target contract | No numerical dependency | No physics qualification follows |

## Architecture
```text
owned UTF-8 input -> checked scalar cursor -> iterative tag stack
 -> immutable preorder node table with parent indices + original byte locations
 -> bounded measurement -> bounded escaped UTF-8 output
```

## Contracts and Invariants
Accept strict UTF-8 with optional initial BOM, XML1.0 characters, exactly one element root, matching lexical names, quoted unique attributes, empty tags, mixed text, comments and CDATA. Accept optional declaration only immediately after BOM, version exactly 1.0, optional encoding case-insensitive UTF-8 and optional standalone yes/no in XML-defined order. Reject other declarations, DTDs, processing instructions, custom/external entities and encodings explicitly. References accept five predefined entities and checked decimal/hexadecimal XML scalars. Raw CR/CRLF normalize to LF; raw attribute tab/LF/CR normalize to space, while character-reference whitespace is retained. No whitespace trimming or Unicode normalization.

Names use XML1.0 Fifth Edition NameStartChar/NameChar excluding colon. Namespace-bearing names and `xmlns` attributes are unsupported; every admitted name is its local name and has no namespace URI. No adapter may infer a prefix mapping or silently strip prefixes. XML lexical equality is UTF-8 equality, avoiding Swift canonical-equivalence matching. Unsupported namespace documents fail rather than being reinterpreted.

`XMLDocument.nodes` is a preorder forest: only comments may be outside the root, every non-root element/text has a previously defined element parent still open, and one root element occurs at `rootIndex`. CDATA is ordinary text; lexical CDATA/escaping/quote style/empty-tag form/BOM/outer whitespace are not preserved. Adjacent text segmentation is not semantic. The writer preserves declaration presence/standalone, element/attribute lexical names and order, normalized text/attribute values, comment content/order and parent relationships. It escapes ampersand, angle brackets, quotes and reference-preserving whitespace. Writer validates caller-created tables before publishing bytes, including duplicate attributes, parent topology, characters and comment grammar.

## Runtime Flows
Parser validates every input scalar before syntax traversal. All cursor movement and payload traversal charge operations and check cancellation. Parser and writer return only a complete document/buffer or XMLFailure; caller work retains consumed budget on failure. Writer measures first and charges output storage before allocation; the second pass uses identical immutable input and limits. No partial output or filesystem side effect.

## State, Ownership, and Lifecycle
Input is immutable Array COW storage held for the synchronous operation. Nodes own decoded Strings/attributes; indices refer to this returned document only. Cursor, node array, stacks and output buffer have exclusive operation-local mutation. Public immutable records and operation services are Sendable with identical Native/WASM/Embedded contracts. No raw pointer, escaping view, shared mutable state or shutdown resource.

## Failure, Concurrency, and Constraints
Caller selects nonnegative input/output bytes, nodes, cumulative attributes, attributes per element, depth, cumulative decoded payload bytes, cumulative logical storage and operations. Limits have no guessed correctness defaults. Checked additions reject overflow. Logical storage charges requested node/attribute/stack strides, decoded UTF-8 payload and measured output bytes; it excludes caller input storage, allocator capacity/overhead and runtime representation overhead. Work is cumulative across calls. Input size is checked before traversal, depth before stack insertion, and node/attribute counts before record insertion. Duplicate/name comparisons are charged. Cancellation is checked at entry, charged steps and before publication. No wall-clock, allocator-total or measured zero-copy claim.

Diagnostics contain original zero-based byte offset, one-based line and one-based byte column; CRLF is one newline. Caller-created writer records use their supplied location for diagnostics. Byte locations are provenance, not serialized content.

## Verification and Change Impact
The selected restricted subset is qualified through actual public protocol calls, independent mixed-content/declaration/comment/entity normalization records and writer bytes, malformed input/table rejection, exact limits, overflow, cancellation and consumed failure-work receipts. Evidence and exact target premises are owned by [XMLQualification](../../../../Verification/XMLQualification/DESIGN.md). Native canonical MechanicsXMLTests executes the same nine test bodies in the actual SwiftMechanics module. The exact-source standalone ordinary/Embedded WASI public probes passed their original 131072-byte guards before raw execution. This does not establish foreign semantic adapters, general XML conformance or broader platform capability. Budget/normalization/name changes invalidate dependent adapter assumptions.
