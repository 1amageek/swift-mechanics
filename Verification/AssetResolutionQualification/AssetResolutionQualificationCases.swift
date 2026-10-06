import SwiftMechanics

public enum AssetResolutionQualificationCases {
    public static func policy(roots: Int = 8, references: Int = 16, edges: Int = 32, depth: Int = 16,
                              string: Int = 128, metadata: Int = 16384, asset: Int = 1024,
                              total: Int = 4096, storage: Int = 65536, operations: Int = 100000,
                              formats: [String] = ["f"]) throws -> AssetResolutionPolicy {
        try AssetResolutionPolicy(maximumRoots: roots, maximumReferences: references, maximumEdges: edges,
            maximumDepth: depth, maximumStringBytes: string, maximumMetadataBytes: metadata,
            maximumAssetBytes: asset, maximumTotalBytes: total, maximumStorageBytes: storage,
            maximumOperations: operations, assetFormats: formats)
    }

    public static func providerPolicy(inventory: Int = 16, reads: Int = 32, bytes: Int = 4096,
                                      operations: Int = 100000) throws -> AssetProviderPolicy {
        try AssetProviderPolicy(maximumInventoryRecords: inventory, maximumReads: reads,
            maximumBytesRead: bytes, maximumOperations: operations)
    }

    public static func work(policy: AssetResolutionPolicy? = nil,
                            provider: AssetProviderPolicy? = nil) throws -> AssetResolutionWork {
        AssetResolutionWork(policy: try policy ?? self.policy(), providerPolicy: try provider ?? providerPolicy())
    }

    public static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw AssetResolutionQualificationError.assertion(message) }
    }

    public static func same(_ first: AssetAddress, _ second: AssetAddress) -> Bool {
        first.base.utf8.elementsEqual(second.base.utf8) && first.relativePath.utf8.elementsEqual(second.relativePath.utf8)
    }

    static func resolve(_ fixture: AssetResolutionQualificationFixture,
                        work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> AssetResolvedCatalog {
        let resolver: any AssetResolving = BoundedAssetResolver(provider: MemoryAssetProvider(records: fixture.records))
        return try resolver.resolve(roots: fixture.roots, inventory: fixture.inventory, work: &work)
    }

    @discardableResult
    static func refused(_ fixture: AssetResolutionQualificationFixture, work: inout AssetResolutionWork,
                        matching: (AssetResolutionFailure) -> Bool) throws -> AssetResolutionFailure {
        do throws(AssetResolutionFailure) { _ = try resolve(fixture, work: &work) }
        catch {
            try check(matching(error), "Unexpected typed resolution failure or failing address")
            return error
        }
        throw AssetResolutionQualificationError.assertion("Invalid resolution published a successful catalog")
    }

    static func address(_ failure: AssetResolutionFailure, _ expected: AssetAddress?) -> Bool {
        switch (failure.address, expected) {
        case (nil, nil): return true
        case (.some(let actual), .some(let wanted)): return same(actual, wanted)
        default: return false
        }
    }

    static func limit(_ failure: AssetResolutionFailure, resource: AssetResource, value: Int) -> Bool {
        guard case .limit(let actual, let actualValue) = failure.reason else { return false }
        return actual == resource && actualValue == value
    }

    static func providerLimit(_ failure: AssetResolutionFailure, resource: AssetResource, value: Int) -> Bool {
        guard case .provider(.limit(let actual, let actualValue)) = failure.reason else { return false }
        return actual == resource && actualValue == value
    }

    public static func originalProviderAndExactWork() throws {
        let fixture = try AssetResolutionQualificationFixture.single()
        let provider: any AssetProviding = MemoryAssetProvider(records: fixture.records)
        let limits = try AssetReadLimits(maximumBytes: 3, maximumDependencies: 0, maximumStringBytes: 1, maximumMetadataBytes: 5)
        var ledger = AssetProviderWork(policy: try providerPolicy(inventory: 1, reads: 1, bytes: 3, operations: 14))
        let result = try provider.read(address: AssetAddress(base: "b", relativePath: "p"), limits: limits, work: &ledger)
        try check(result.asset.bytes == [0, 255, 17] && result.asset.key == "k" && result.asset.format == "f", "Original opaque bytes/key/format")
        try check(result.asset.provenance.source == "s" && result.asset.provenance.revision == 7 && result.dependencies.isEmpty,
                  "Original provenance and empty dependency declaration")
        try check(same(result.address, AssetAddress(base: "b", relativePath: "p")), "Explicit original base/path")
        try check(ledger.reads == 1 && ledger.bytesRead == 3 && ledger.operations == 14, "Independent exact memory read work oracle")
        for byteCap in [2, 3] {
            let limits = try AssetReadLimits(maximumBytes: byteCap, maximumDependencies: 0, maximumStringBytes: 1, maximumMetadataBytes: 5)
            var prefix = AssetProviderWork(policy: try providerPolicy(inventory: 1, reads: 1, bytes: 2))
            var failed = false
            do throws(AssetProviderFailure) { _ = try provider.read(address: fixture.roots[0], limits: limits, work: &prefix) }
            catch {
                switch error {
                case .limit(.assetBytes, 2): failed = byteCap == 2
                case .limit(.providerBytes, 2): failed = byteCap == 3
                default: break
                }
            }
            try check(failed, "Actual prefix capacity has the operation-specific typed failure")
            try check(prefix.reads == 1 && prefix.bytesRead == 2 && prefix.operations == 13, "Known prefix bytes/work survive failure without retry")
        }
        let ambiguous: any AssetProviding = MemoryAssetProvider(records: [fixture.records[0], fixture.records[0]])
        var ambiguityWork = AssetProviderWork(policy: try providerPolicy())
        var ambiguityFailed = false
        do throws(AssetProviderFailure) { _ = try ambiguous.read(address: fixture.roots[0], limits: limits, work: &ambiguityWork) }
        catch { if case .ambiguous = error { ambiguityFailed = true } }
        try check(ambiguityFailed && ambiguityWork.reads == 1 && ambiguityWork.bytesRead == 0 && ambiguityWork.operations == 11,
                  "Actual duplicated source lookup refuses ambiguity with independent exact scan work")
    }

    public static func diamondAndNativeCatalog() throws {
        let fixture = try AssetResolutionQualificationFixture.diamond()
        var ledger = try work()
        let catalog = try resolve(fixture, work: &ledger)
        try check(catalog.records.count == 4 && catalog.roots.count == 2, "Selected complete closure count")
        try check(same(catalog.roots[0], AssetAddress(base: "b", relativePath: "a")) &&
                  same(catalog.roots[1], AssetAddress(base: "b", relativePath: "c")), "Original selected root order")
        let keys = ["D", "B", "C", "A"], sources = ["srcD", "srcB", "srcC", "srcA"]
        let revisions: [UInt64] = [2, 9, 12, 7]
        let bytes: [[UInt8]] = [[42, 254, 63, 5], [17], [128, 0, 7], [0, 255]]
        let paths = ["d", "b", "c", "a"], dependencyPaths = [[], ["d"], ["d"], ["b", "c"]]
        for i in 0..<4 {
            let actual = catalog.records[i]
            try check(actual.asset.key == keys[i] && actual.asset.bytes == bytes[i] && actual.asset.format == "f", "Independent literal closure order/bytes")
            try check(actual.asset.provenance.source == sources[i] && actual.asset.provenance.revision == revisions[i], "Independent original source/revisions")
            try check(same(actual.address, AssetAddress(base: "b", relativePath: paths[i])), "Original child address attribution")
            try check(actual.dependencies.count == dependencyPaths[i].count, "Original declared dependency count")
            for j in actual.dependencies.indices {
                try check(same(actual.dependencies[j], AssetAddress(base: "b", relativePath: dependencyPaths[i][j])), "Original dependency order")
            }
        }
        try check(ledger.provider.reads == 4 && ledger.provider.bytesRead == 10 && ledger.validatedPayloadBytes == 10,
                  "Diamond shared child and selected completed root are read once")
        let view: any AssetCatalogReading = catalog
        var queryWork = try work()
        let native = try view.nativeAssets(work: &queryWork)
        try check(native.count == 4, "Public native projection returns complete closure")
        for i in 0..<4 {
            try check(native[i].key == keys[i] && native[i].format == "f" && native[i].bytes == bytes[i] &&
                      native[i].provenance.source == sources[i] && native[i].provenance.revision == revisions[i],
                      "Every projected native asset matches independent original bytes/source/revision")
        }
        let queried = try view.asset(address: AssetAddress(base: "b", relativePath: "c"), work: &queryWork)
        try check(queried.asset.key == "C" && queried.asset.bytes == [128, 0, 7] && queried.asset.provenance.revision == 12, "Public exact-address catalog lookup")
        try check(queryWork.provider.reads == 0 && queryWork.provider.bytesRead == 0 && queryWork.validatedPayloadBytes == 0,
                  "Immutable catalog projection/lookup does not fabricate rereads or revalidation receipts")
    }

    public static func dependencyAndMetadataRefusals() throws {
        let original = try AssetResolutionQualificationFixture.single()
        for actual in try [
            AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 18]),
            AssetResolutionQualificationFixture.record(key: "other", path: "p", bytes: [0, 255, 17]),
            AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17], source: "changed"),
            AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17], revision: 8),
            AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17], format: "g")
        ] {
            let fixture = AssetResolutionQualificationFixture(roots: original.roots, inventory: original.inventory, records: [actual])
            var ledger = try work()
            try refused(fixture, work: &ledger) { failure in
                guard address(failure, original.roots[0]) else { return false }
                if actual.asset.bytes == [0, 255, 18] { if case .bytesMismatch = failure.reason { return true } }
                else { if case .metadataMismatch = failure.reason { return true } }
                return false
            }
            try check(ledger.provider.reads == 1 && ledger.provider.bytesRead == 3 && ledger.validatedPayloadBytes == 0,
                      "Read mismatches retain actual known read but validate no payload")
        }
        let graph = try AssetResolutionQualificationFixture.diamond()
        let reordered = try AssetResolutionQualificationFixture.record(key: "A", path: "a", bytes: [0, 255],
            dependencies: [AssetAddress(base: "b", relativePath: "c"), AssetAddress(base: "b", relativePath: "b")], source: "srcA", revision: 7)
        let altered = AssetResolutionQualificationFixture(roots: graph.roots, inventory: graph.inventory,
            records: [graph.records[0], reordered, graph.records[2], graph.records[3]])
        var orderWork = try work()
        try refused(altered, work: &orderWork) { failure in
            if case .dependencyMismatch = failure.reason { return address(failure, AssetAddress(base: "b", relativePath: "a")) }; return false
        }
        try check(orderWork.provider.reads == 1 && orderWork.provider.bytesRead == 2 && orderWork.validatedPayloadBytes == 0,
                  "Provider dependency order is verified before child traversal")
        let oversized = try AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17, 99])
        var oversizeWork = try work()
        try refused(AssetResolutionQualificationFixture(roots: original.roots, inventory: original.inventory, records: [oversized]), work: &oversizeWork) {
            providerLimit($0, resource: .assetBytes, value: 3) && address($0, original.roots[0])
        }
        try check(oversizeWork.provider.bytesRead == 3 && oversizeWork.validatedPayloadBytes == 0, "Oversized source records only its bounded known prefix")
        let unicodeExpected = try AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17], source: "é")
        let unicodeActual = try AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17], source: "e\u{301}")
        var unicodeWork = try work()
        try refused(AssetResolutionQualificationFixture(roots: [unicodeExpected.address], inventory: [AssetResolutionQualificationFixture.request(unicodeExpected)], records: [unicodeActual]), work: &unicodeWork) {
            if case .metadataMismatch = $0.reason { return true }; return false
        }
        let composed = try AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17], base: "é")
        let decomposed = try AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0, 255, 17], base: "e\u{301}")
        var addressWork = try work()
        try refused(AssetResolutionQualificationFixture(roots: [decomposed.address], inventory: [AssetResolutionQualificationFixture.request(decomposed)], records: [composed]), work: &addressWork) {
            if case .provider(.missing) = $0.reason { return address($0, decomposed.address) }; return false
        }
        try check(addressWork.provider.reads == 1 && addressWork.provider.bytesRead == 0, "Unicode-equivalent base is not an exact source lookup")
    }

    public static func graphAdmissionRefusals() throws {
        let graph = try AssetResolutionQualificationFixture.diamond()
        let a = AssetAddress(base: "b", relativePath: "a"), b = AssetAddress(base: "b", relativePath: "b")
        let d = AssetAddress(base: "b", relativePath: "d")
        var depthWork = try work(policy: policy(depth: 1))
        try refused(graph, work: &depthWork) { limit($0, resource: .depth, value: 1) && address($0, b) }
        try check(depthWork.provider.reads == 1 && depthWork.provider.bytesRead == 2 && depthWork.validatedPayloadBytes == 2, "Depth refuses before a child read and retains staged root work")
        let ra = try AssetResolutionQualificationFixture.record(key: "A", path: "a", bytes: [0, 255], dependencies: [b])
        let rb = try AssetResolutionQualificationFixture.record(key: "B", path: "b", bytes: [17], dependencies: [a])
        let cycle = AssetResolutionQualificationFixture(roots: [a], inventory: [AssetResolutionQualificationFixture.request(ra), AssetResolutionQualificationFixture.request(rb)], records: [rb, ra])
        var cycleWork = try work()
        try refused(cycle, work: &cycleWork) { if case .cycle = $0.reason { return address($0, a) }; return false }
        try check(cycleWork.provider.reads == 2 && cycleWork.provider.bytesRead == 3 && cycleWork.validatedPayloadBytes == 3, "Cycle failure retains two actual validated reads without revisiting source")
        let missing = AssetResolutionQualificationFixture(roots: graph.roots,
            inventory: [graph.inventory[0], graph.inventory[2], graph.inventory[3]], records: graph.records)
        var missingWork = try work()
        try refused(missing, work: &missingWork) { if case .missingDeclaration = $0.reason { return address($0, d) }; return false }
        try check(missingWork.provider.reads == 0 && missingWork.validatedPayloadBytes == 0, "Full declaration closure fails before any source lookup")
        let missingSource = AssetResolutionQualificationFixture(roots: graph.roots, inventory: graph.inventory,
            records: [graph.records[0], graph.records[1], graph.records[3]])
        var providerWork = try work()
        try refused(missingSource, work: &providerWork) { if case .provider(.missing) = $0.reason { return address($0, d) }; return false }
        try check(providerWork.provider.reads == 3 && providerWork.provider.bytesRead == 3 && providerWork.validatedPayloadBytes == 3,
                  "Missing third source retains A/B prefix with no retry or partial catalog")
        let single = try AssetResolutionQualificationFixture.single(), original = single.records[0]
        let duplicateAddress = try AssetResolutionQualificationFixture.record(key: "other", path: "p", bytes: [9])
        let duplicateKey = try AssetResolutionQualificationFixture.record(key: "k", path: "q", bytes: [9])
        for (added, isAddress) in [(duplicateAddress, true), (duplicateKey, false)] {
            var ledger = try work()
            try refused(AssetResolutionQualificationFixture(roots: single.roots, inventory: [single.inventory[0], AssetResolutionQualificationFixture.request(added)], records: [original, added]), work: &ledger) {
                if isAddress { if case .duplicateAddress = $0.reason { return address($0, added.address) } }
                else { if case .duplicateKey = $0.reason { return address($0, added.address) } }; return false
            }
            try check(ledger.provider.reads == 0, "Duplicate declarations fail before reads")
        }
        var rootWork = try work()
        try refused(AssetResolutionQualificationFixture(roots: [single.roots[0], single.roots[0]], inventory: single.inventory, records: single.records), work: &rootWork) {
            if case .duplicateRoot = $0.reason { return address($0, single.roots[0]) }; return false
        }
        let repeated = try AssetResolutionQualificationFixture.record(key: "A", path: "a", bytes: [1], dependencies: [b, b])
        var edgeWork = try work()
        try refused(AssetResolutionQualificationFixture(roots: [a], inventory: [AssetResolutionQualificationFixture.request(repeated), AssetResolutionQualificationFixture.request(rb)], records: [repeated, rb]), work: &edgeWork) {
            if case .duplicateDependency = $0.reason { return address($0, b) }; return false
        }
        for path in ["", "end/", "/absolute", "../escape", "a/./b", "a//b", "http:asset", "a%2fb", "a?query", "a#fragment", "a\\b", "a\u{0}b"] {
            let unsafe = try AssetResolutionQualificationFixture.record(key: "k", path: path, bytes: [0])
            var ledger = try work()
            try refused(AssetResolutionQualificationFixture(roots: [unsafe.address], inventory: [AssetResolutionQualificationFixture.request(unsafe)], records: [unsafe]), work: &ledger) {
                if case .invalidReference = $0.reason { return address($0, unsafe.address) }; return false
            }
            try check(ledger.provider.reads == 0, "Unsafe explicit references cause no hidden source access")
        }
        for base in ["", "base\u{0}", "base\n"] {
            let unsafe = try AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0], base: base)
            var ledger = try work()
            try refused(AssetResolutionQualificationFixture(roots: [unsafe.address], inventory: [AssetResolutionQualificationFixture.request(unsafe)], records: [unsafe]), work: &ledger) {
                if case .invalidReference = $0.reason { return address($0, unsafe.address) }; return false
            }
            try check(ledger.provider.reads == 0, "Missing or control-bearing explicit base causes no implicit lookup")
        }
        let unsupported = try AssetResolutionQualificationFixture.record(key: "k", path: "p", bytes: [0], format: "g")
        var formatWork = try work()
        try refused(AssetResolutionQualificationFixture(roots: [unsupported.address], inventory: [AssetResolutionQualificationFixture.request(unsupported)], records: [unsupported]), work: &formatWork) {
            if case .unsupportedFormat = $0.reason { return true }; return false
        }
        try check(formatWork.provider.reads == 0, "Unknown format is not admitted as physical geometry")
    }

    public static func exactResolutionWorkAndBoundaries() throws {
        let fixture = try AssetResolutionQualificationFixture.single()
        let exact = try policy(roots: 1, references: 1, edges: 0, depth: 1, string: 1, metadata: 13, asset: 3, total: 3, operations: 50)
        var ledger = try work(policy: exact, provider: providerPolicy(inventory: 1, reads: 1, bytes: 3, operations: 14))
        let catalog = try resolve(fixture, work: &ledger)
        try check(catalog.records.count == 1 && catalog.records[0].asset.bytes == [0, 255, 17], "All independent exact limits admit original bytes")
        try check(ledger.operations == 50 && ledger.metadataBytes == 13 && ledger.validatedPayloadBytes == 3 && ledger.storageBytes > 3,
                  "Independent resolver original 50/13/3 work oracle")
        try check(ledger.provider.operations == 14 && ledger.provider.reads == 1 && ledger.provider.bytesRead == 3, "Independent resolver actual provider ledger")
        var finalWork = try work(policy: policy(operations: 49))
        try refused(fixture, work: &finalWork) { limit($0, resource: .operations, value: 49) && address($0, nil) }
        try check(finalWork.operations == 49 && finalWork.validatedPayloadBytes == 3 && finalWork.provider.bytesRead == 3,
                  "Final publication failure returns no catalog while retaining complete staged source work")
        let boundaries: [(AssetResource, Int, AssetResolutionPolicy)] = try [
            (.roots, 0, policy(roots: 0)), (.references, 0, policy(references: 0, formats: [])),
            (.depth, 0, policy(depth: 0)), (.stringBytes, 0, policy(string: 0)),
            (.metadataBytes, 0, policy(metadata: 0)), (.assetBytes, 2, policy(asset: 2)),
            (.totalBytes, 2, policy(total: 2)), (.storageBytes, 0, policy(storage: 0)), (.operations, 0, policy(operations: 0))
        ]
        for (resource, cap, selected) in boundaries {
            var refusedWork = try work(policy: selected)
            try refused(fixture, work: &refusedWork) { limit($0, resource: resource, value: cap) }
            try check(refusedWork.provider.reads == 0 && refusedWork.validatedPayloadBytes == 0, "Admission limit stops before provider access")
        }
        let graph = try AssetResolutionQualificationFixture.diamond()
        var edgeWork = try work(policy: policy(edges: 0))
        try refused(graph, work: &edgeWork) { limit($0, resource: .edges, value: 0) }
        try check(edgeWork.provider.reads == 0, "Edge cap precedes source access")
        var cumulative = try work(policy: policy(operations: 100), provider: providerPolicy(reads: 2, bytes: 6, operations: 28))
        _ = try resolve(fixture, work: &cumulative); _ = try resolve(fixture, work: &cumulative)
        try check(cumulative.operations == 100 && cumulative.metadataBytes == 26 && cumulative.validatedPayloadBytes == 6 &&
                  cumulative.provider.reads == 2 && cumulative.provider.bytesRead == 6 && cumulative.provider.operations == 28,
                  "Two actual resolutions retain cumulative exact ledger without resetting")
        try refused(fixture, work: &cumulative) { limit($0, resource: .operations, value: 100) }
        try check(cumulative.operations == 100 && cumulative.provider.reads == 2 && cumulative.validatedPayloadBytes == 6,
                  "Refused next invocation does not erase consumed work")
    }

    public static func providerAndCatalogLimits() throws {
        let fixture = try AssetResolutionQualificationFixture.single()
        let providerCaps: [(AssetResource, Int, AssetProviderPolicy, Int, Int, Int)] = try [
            (.providerInventory, 0, providerPolicy(inventory: 0), 1, 0, 1),
            (.providerReads, 0, providerPolicy(reads: 0), 0, 0, 1),
            (.providerBytes, 2, providerPolicy(bytes: 2), 1, 2, 13),
            (.providerOperations, 0, providerPolicy(operations: 0), 0, 0, 0)
        ]
        for (resource, cap, selected, reads, bytes, operations) in providerCaps {
            var ledger = try work(provider: selected)
            try refused(fixture, work: &ledger) { providerLimit($0, resource: resource, value: cap) && address($0, fixture.roots[0]) }
            try check(ledger.provider.reads == reads && ledger.provider.bytesRead == bytes && ledger.provider.operations == operations &&
                      ledger.validatedPayloadBytes == 0, "Exact actual failed provider receipt, no fabricated retry")
        }
        var publishedWork = try work()
        var published = try resolve(fixture, work: &publishedWork)
        var failedWork = try work(provider: providerPolicy(bytes: 2))
        var failed = false
        do throws(AssetResolutionFailure) { published = try resolve(fixture, work: &failedWork) }
        catch { failed = providerLimit(error, resource: .providerBytes, value: 2) }
        try check(failed && published.records.count == 1 && published.records[0].asset.bytes == [0, 255, 17], "Prior immutable catalog survives failed attempted replacement")
        let view: any AssetCatalogReading = published
        let queryCaps: [(AssetResource, Int, AssetResolutionPolicy)] = try [
            (.references, 0, policy(references: 0, formats: [])), (.totalBytes, 2, policy(total: 2)), (.assetBytes, 2, policy(asset: 2))
        ]
        for (resource, cap, selected) in queryCaps {
            var queryWork = try work(policy: selected)
            var failed = false
            do throws(AssetResolutionFailure) { _ = try view.nativeAssets(work: &queryWork) }
            catch {
                failed = limit(error, resource: resource, value: cap)
            }
            try check(failed && queryWork.provider.reads == 0, "Projection honors current tighter record/payload cap with no reread")
        }
        let graph = try AssetResolutionQualificationFixture.diamond()
        var graphWork = try work()
        let catalog = try resolve(graph, work: &graphWork)
        let graphView: any AssetCatalogReading = catalog
        var edgeWork = try work(policy: policy(edges: 1))
        var edgesFailed = false
        do throws(AssetResolutionFailure) { _ = try graphView.asset(address: AssetAddress(base: "b", relativePath: "a"), work: &edgeWork) }
        catch { edgesFailed = limit(error, resource: .edges, value: 1) }
        try check(edgesFailed && edgeWork.provider.reads == 0, "Lookup honors tighter dependency cap while retaining original catalog")
    }

    public static func checkedLedgerArithmetic() throws {
        var ledger = try work(policy: policy(operations: Int.max))
        try ledger.charge(Int.max)
        var failed = false
        do throws(AssetResolutionFailure) { try ledger.charge(1) }
        catch { if case .arithmeticOverflow = error.reason { failed = true } }
        try check(failed && ledger.operations == Int.max && ledger.provider.reads == 0 && ledger.validatedPayloadBytes == 0,
                  "Public resolver ledger overflow leaves known counter intact without claiming provider work")
        var provider = AssetProviderWork(policy: try providerPolicy(operations: Int.max))
        try provider.charge(Int.max)
        var providerFailed = false
        do throws(AssetProviderFailure) { try provider.charge(1) }
        catch { if case .arithmeticOverflow = error { providerFailed = true } }
        try check(providerFailed && provider.operations == Int.max && provider.reads == 0 && provider.bytesRead == 0,
                  "Public provider ledger arithmetic refuses overflow without an invented read")
    }

    public static func cancelledTask() throws {
        try check(Task.isCancelled, "Cancellation case requires an actual cancelled Task")
        let fixture = try AssetResolutionQualificationFixture.single()
        var ledger = try work()
        try refused(fixture, work: &ledger) { if case .cancelled = $0.reason { return address($0, nil) }; return false }
        try check(ledger.operations == 0 && ledger.storageBytes == 0 && ledger.metadataBytes == 0 &&
                  ledger.provider.reads == 0 && ledger.provider.bytesRead == 0 && ledger.validatedPayloadBytes == 0,
                  "Cancellation before admission does no source work and publishes no catalog")
    }
}
