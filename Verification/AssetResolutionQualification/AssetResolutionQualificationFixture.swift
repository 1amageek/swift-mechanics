import SwiftMechanics

public struct AssetResolutionQualificationFixture: Sendable {
    public let roots: [AssetAddress]
    public let inventory: [AssetRequest]
    public let records: [AssetProviderRecord]

    public init(roots: [AssetAddress], inventory: [AssetRequest], records: [AssetProviderRecord]) {
        self.roots = roots; self.inventory = inventory; self.records = records
    }

    public static func record(key: String, path: String, bytes: [UInt8], dependencies: [AssetAddress] = [],
                              source: String = "s", revision: UInt64 = 7, base: String = "b",
                              format: String = "f") throws -> AssetProviderRecord {
        AssetProviderRecord(address: AssetAddress(base: base, relativePath: path),
            asset: NativeInlineAsset(key: key, format: format,
                provenance: try SourceProvenance(source: source, revision: revision), bytes: bytes),
            dependencies: dependencies)
    }

    public static func request(_ record: AssetProviderRecord) -> AssetRequest {
        AssetRequest(address: record.address, original: record.asset, dependencies: record.dependencies)
    }

    public static func single() throws -> AssetResolutionQualificationFixture {
        let original = try record(key: "k", path: "p", bytes: [0, 255, 17])
        return AssetResolutionQualificationFixture(roots: [original.address], inventory: [request(original)], records: [original])
    }

    public static func diamond() throws -> AssetResolutionQualificationFixture {
        let a = AssetAddress(base: "b", relativePath: "a"), b = AssetAddress(base: "b", relativePath: "b")
        let c = AssetAddress(base: "b", relativePath: "c"), d = AssetAddress(base: "b", relativePath: "d")
        let ra = try record(key: "A", path: "a", bytes: [0, 255], dependencies: [b, c], source: "srcA", revision: 7)
        let rb = try record(key: "B", path: "b", bytes: [17], dependencies: [d], source: "srcB", revision: 9)
        let rc = try record(key: "C", path: "c", bytes: [128, 0, 7], dependencies: [d], source: "srcC", revision: 12)
        let rd = try record(key: "D", path: "d", bytes: [42, 254, 63, 5], source: "srcD", revision: 2)
        return AssetResolutionQualificationFixture(roots: [a, c],
            inventory: [request(rc), request(rd), request(ra), request(rb)], records: [rc, ra, rd, rb])
    }
}
