public struct AssetResolvedCatalog: AssetCatalogReading {
    public let roots: [AssetAddress]
    /// Dependency-first order. Every record belongs to the complete selected-root closure.
    public let records: [AssetProviderRecord]
    internal init(roots: [AssetAddress], records: [AssetProviderRecord]) { self.roots = roots; self.records = records }
    public func nativeAssets(work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> [NativeInlineAsset] {
        try work.limit(records.count, maximum: work.policy.maximumReferences, resource: .references)
        try work.allocate(records.count, stride: MemoryLayout<NativeInlineAsset>.stride)
        var assets: [NativeInlineAsset] = []; assets.reserveCapacity(records.count)
        var total = 0
        for record in records {
            try AssetReferenceValidation.metadata(record.asset, address: record.address, work: &work)
            total = try AssetResolutionWork.sum(total, record.asset.bytes.count, address: record.address)
            try work.limit(total, maximum: work.policy.maximumTotalBytes, resource: .totalBytes, address: record.address)
            assets.append(record.asset)
        }
        try work.charge(1)
        return assets
    }
    public func asset(address: AssetAddress, work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> AssetProviderRecord {
        try work.limit(records.count, maximum: work.policy.maximumReferences, resource: .references)
        try AssetReferenceValidation.address(address, work: &work)
        for record in records {
            if try AssetReferenceValidation.same(record.address, address, work: &work) {
                try AssetReferenceValidation.metadata(record.asset, address: address, work: &work)
                try work.limit(record.asset.bytes.count, maximum: work.policy.maximumTotalBytes, resource: .totalBytes, address: address)
                try work.limit(record.dependencies.count, maximum: work.policy.maximumEdges, resource: .edges, address: address)
                for dependency in record.dependencies { try AssetReferenceValidation.address(dependency, work: &work) }
                return record
            }
        }
        throw AssetResolutionFailure(.missingDeclaration, address: address)
    }
}
