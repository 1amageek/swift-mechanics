# SwiftMechanicsCAD companion package

## Purpose and Scope
This independent SwiftPM development companion maps admitted exact CAD geometry queries into mechanics occurrence frames. Its parent is [SwiftMechanics](../../DESIGN.md); its child is the [SwiftMechanicsCAD module](Sources/SwiftMechanicsCAD/DESIGN.md). It does not complete IM38 or CA-003/004.

## Responsibilities and Boundaries
The package imports the companion mechanics workspace and public products of remote Swift-CAD revision `295a724cdf0219c904007c2735f2b99ef08200ca`. The core package has no dependency on this package or CAD. CAD owns evaluation and geometric integration; this package owns source association, explicit occurrences and mechanical coordinate conversion. This is Native macOS development integration, without release, WASM or Embedded claims.

## Related Designs
| Design | Relationship | Contract used | Summary | Caution |
|---|---|---|---|---|
| [Mechanics](../../DESIGN.md) | parent | Public frames, identifiers and provenance | Mechanics value conversion | No CAD import in core |
| [Module](Sources/SwiftMechanicsCAD/DESIGN.md) | child | Selected geometry admission | Selected adapter responsibility | Exact solid moments remain unavailable |
| [Tests](Tests/SwiftMechanicsCADTests/DESIGN.md) | used by | Original query and stale-source oracles | Owned behavioral proof | Independent clean-pin Native execution |

## Architecture
```text
remote pinned CAD public products -> SwiftMechanicsCAD -> public mechanics values
caller occurrences/materials -----------^
core package -> no adapter/CAD dependency
```

## Contracts and Invariants
The companion manifest alone resolves CADCore, CADGeometry, CADTopology, CADIR, CADModeling and CADKernel. CAD's package graph also resolves its pinned OpenUSD and collections dependencies despite selected targets not linking exchange. Local mechanics dependency is intentional development configuration, not release certification. No adapter result grants Runtime model publication or physical-state migration authority.

## Verification and Change Impact
The adapter owner runs the frozen whole companion package tests using Swift 6.4.0 in an immutable mechanics baseline copy, with setup timeout 1200 seconds, four jobs and behavior timeout 240 seconds. Root owns external public composition and commits. Parent core profile evidence remains separate; no unexecuted CAD profile is qualified.

The owner's actual release compile/link and 9-test whole companion Native behavior passed; exact commands, immutable baseline/provider checks and source/log digests are in the [test evidence](Tests/SwiftMechanicsCADTests/DESIGN.md#executed-af28-native-evidence). The generated private resolved graph binds CAD 295a724, collections 1.5.1/fea17c0 and OpenUSD 2c943c7. Root owns promotion of Package.resolved and independent external caller proof.
