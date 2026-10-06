public struct BoundedAssetResolver<Provider: AssetProviding>: AssetResolving {
    private struct Frame { let index: Int; var child = 0 }
    public let provider: Provider
    public init(provider: Provider) { self.provider = provider }

    public func resolve(roots: [AssetAddress], inventory: [AssetRequest],
                        work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> AssetResolvedCatalog {
        try preflight(roots: roots, inventory: inventory, work: &work)
        let count = inventory.count, frameCapacity = min(work.policy.maximumDepth, count)
        try work.allocate(count, stride: MemoryLayout<UInt8>.stride)
        try work.allocate(count, stride: MemoryLayout<AssetProviderRecord?>.stride)
        try work.allocate(count, stride: MemoryLayout<AssetProviderRecord>.stride)
        try work.allocate(frameCapacity, stride: MemoryLayout<Frame>.stride)
        try work.allocate(roots.count, stride: MemoryLayout<AssetAddress>.stride)
        var visited = [UInt8](repeating: 0, count: count)
        var staged = [AssetProviderRecord?](repeating: nil, count: count)
        var completed: [AssetProviderRecord] = [], frames: [Frame] = []
        completed.reserveCapacity(count); frames.reserveCapacity(frameCapacity)
        for root in roots {
            let index = try AssetReferenceValidation.index(root, inventory: inventory, work: &work)
            if visited[index] == 2 { continue }
            try work.limit(1, maximum: work.policy.maximumDepth, resource: .depth, address: root)
            frames.append(Frame(index: index))
            while !frames.isEmpty {
                try work.charge(1, address: inventory[frames[frames.count - 1].index].address)
                let position = frames.count - 1, index = frames[position].index
                let request = inventory[index]
                if visited[index] == 0 {
                    let record = try read(request, work: &work)
                    staged[index] = record; visited[index] = 1
                }
                guard let record = staged[index] else { throw AssetResolutionFailure(.invalidInput, address: request.address) }
                if frames[position].child < record.dependencies.count {
                    let address = record.dependencies[frames[position].child]
                    frames[position].child += 1
                    let child = try AssetReferenceValidation.index(address, inventory: inventory, work: &work)
                    if visited[child] == 1 { throw AssetResolutionFailure(.cycle, address: address) }
                    if visited[child] == 2 { continue }
                    let depth = try AssetResolutionWork.sum(frames.count, 1, address: address)
                    try work.limit(depth, maximum: work.policy.maximumDepth, resource: .depth, address: address)
                    frames.append(Frame(index: child))
                } else {
                    completed.append(record); visited[index] = 2; frames.removeLast()
                }
            }
        }
        try work.charge(1)
        return AssetResolvedCatalog(roots: roots, records: completed)
    }

    private func preflight(roots: [AssetAddress], inventory: [AssetRequest],
                           work: inout AssetResolutionWork) throws(AssetResolutionFailure) {
        try work.charge(1)
        guard !roots.isEmpty else { throw AssetResolutionFailure(.invalidInput) }
        try work.limit(roots.count, maximum: work.policy.maximumRoots, resource: .roots)
        try work.limit(inventory.count, maximum: work.policy.maximumReferences, resource: .references)
        for index in work.policy.assetFormats.indices {
            let format = work.policy.assetFormats[index]; try work.text(format)
            guard !format.isEmpty else { throw AssetResolutionFailure(.invalidPolicy) }
            for old in 0..<index {
                _ = try AssetReferenceValidation.same(format, work.policy.assetFormats[old], work: &work)
                // The native format whitelist also prohibits canonical String aliases.
                if format == work.policy.assetFormats[old] { throw AssetResolutionFailure(.invalidPolicy) }
            }
        }
        var edges = 0
        for index in inventory.indices {
            let request = inventory[index]
            try AssetReferenceValidation.address(request.address, work: &work)
            try AssetReferenceValidation.metadata(request.original, address: request.address, work: &work)
            edges = try AssetResolutionWork.sum(edges, request.dependencies.count, address: request.address)
            try work.limit(edges, maximum: work.policy.maximumEdges, resource: .edges, address: request.address)
            var supported = false
            for format in work.policy.assetFormats {
                if try AssetReferenceValidation.same(format, request.original.format, work: &work, address: request.address) { supported = true; break }
            }
            guard supported else { throw AssetResolutionFailure(.unsupportedFormat, address: request.address) }
            for old in 0..<index {
                if try AssetReferenceValidation.same(inventory[old].address, request.address, work: &work) {
                    throw AssetResolutionFailure(.duplicateAddress, address: request.address)
                }
                if try AssetReferenceValidation.same(inventory[old].original.key, request.original.key, work: &work, address: request.address) {
                    throw AssetResolutionFailure(.duplicateKey, address: request.address)
                }
            }
            for child in request.dependencies.indices {
                let address = request.dependencies[child]
                try AssetReferenceValidation.address(address, work: &work)
                for old in 0..<child {
                    if try AssetReferenceValidation.same(request.dependencies[old], address, work: &work) {
                        throw AssetResolutionFailure(.duplicateDependency, address: address)
                    }
                }
            }
        }
        // All declarations, including those not selected by a root, must close over this inventory.
        for request in inventory {
            for address in request.dependencies { _ = try AssetReferenceValidation.index(address, inventory: inventory, work: &work) }
        }
        for index in roots.indices {
            try AssetReferenceValidation.address(roots[index], work: &work)
            _ = try AssetReferenceValidation.index(roots[index], inventory: inventory, work: &work)
            for old in 0..<index {
                if try AssetReferenceValidation.same(roots[old], roots[index], work: &work) {
                    throw AssetResolutionFailure(.duplicateRoot, address: roots[index])
                }
            }
        }
    }

    private func read(_ request: AssetRequest, work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> AssetProviderRecord {
        let remaining = work.policy.maximumTotalBytes - work.validatedPayloadBytes
        try work.limit(request.original.bytes.count, maximum: remaining, resource: .totalBytes, address: request.address)
        try work.allocate(request.original.bytes.count, address: request.address)
        let limits: AssetReadLimits
        do throws(AssetProviderFailure) {
            limits = try AssetReadLimits(maximumBytes: request.original.bytes.count,
                maximumDependencies: request.dependencies.count, maximumStringBytes: work.policy.maximumStringBytes,
                maximumMetadataBytes: work.policy.maximumMetadataBytes - work.metadataBytes)
        } catch { throw AssetResolutionFailure(.provider(error), address: request.address) }
        let before = work.provider, record: AssetProviderRecord
        do throws(AssetProviderFailure) { record = try provider.read(address: request.address, limits: limits, work: &work.provider) }
        catch {
            try receipt(before, work: &work, limit: limits, successfulBytes: nil, cause: error, address: request.address)
            throw AssetResolutionFailure(.provider(error), address: request.address)
        }
        try receipt(before, work: &work, limit: limits, successfulBytes: record.asset.bytes.count, cause: nil, address: request.address)
        try work.charge(1, address: request.address)
        try AssetReferenceValidation.address(record.address, work: &work)
        try AssetReferenceValidation.metadata(record.asset, address: request.address, work: &work)
        guard try AssetReferenceValidation.same(record.address, request.address, work: &work),
              try AssetReferenceValidation.same(record.asset.key, request.original.key, work: &work, address: request.address),
              try AssetReferenceValidation.same(record.asset.format, request.original.format, work: &work, address: request.address),
              try AssetReferenceValidation.same(record.asset.provenance.source, request.original.provenance.source, work: &work, address: request.address),
              record.asset.provenance.revision == request.original.provenance.revision else {
            throw AssetResolutionFailure(.metadataMismatch, address: request.address)
        }
        guard record.asset.bytes.count == request.original.bytes.count else { throw AssetResolutionFailure(.bytesMismatch, address: request.address) }
        for index in record.asset.bytes.indices {
            try work.charge(1, address: request.address)
            guard record.asset.bytes[index] == request.original.bytes[index] else { throw AssetResolutionFailure(.bytesMismatch, address: request.address) }
        }
        guard record.dependencies.count == request.dependencies.count else { throw AssetResolutionFailure(.dependencyMismatch, address: request.address) }
        for index in record.dependencies.indices {
            try AssetReferenceValidation.address(record.dependencies[index], work: &work)
            guard try AssetReferenceValidation.same(record.dependencies[index], request.dependencies[index], work: &work) else {
                throw AssetResolutionFailure(.dependencyMismatch, address: request.address)
            }
        }
        try work.validatedBytes(record.asset.bytes.count, address: request.address)
        return record
    }

    private func receipt(_ before: AssetProviderWork, work: inout AssetResolutionWork, limit: AssetReadLimits,
                         successfulBytes: Int?, cause: AssetProviderFailure?, address: AssetAddress) throws(AssetResolutionFailure) {
        let after = work.provider
        let failure = AssetResolutionFailure(.providerContract(cause: cause, previous: before, observed: after), address: address)
        guard before.policy == after.policy, after.reads >= before.reads, after.bytesRead >= before.bytesRead,
              after.operations >= before.operations else { work.provider = before; throw failure }
        let reads = after.reads - before.reads, bytes = after.bytesRead - before.bytesRead
        guard reads <= 1, bytes <= limit.maximumBytes else { throw failure }
        if let successfulBytes {
            guard reads == 1, bytes == successfulBytes else { throw failure }
        } else if reads == 0, bytes != 0 { throw failure }
    }
}
