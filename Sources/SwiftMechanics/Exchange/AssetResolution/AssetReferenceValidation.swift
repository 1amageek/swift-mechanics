internal enum AssetReferenceValidation {
    static func address(_ address: AssetAddress, work: inout AssetResolutionWork) throws(AssetResolutionFailure) {
        try work.text(address.base, address: address); try work.text(address.relativePath, address: address)
        guard !address.base.isEmpty, !address.relativePath.isEmpty,
              !address.base.utf8.contains(where: { $0 < 32 || $0 == 127 }) else {
            throw AssetResolutionFailure(.invalidReference, address: address)
        }
        let bytes = address.relativePath.utf8
        guard !address.relativePath.hasPrefix("/"), !bytes.contains(where: {
            $0 < 32 || $0 == 127 || $0 == 92 || $0 == 58 || $0 == 37 || $0 == 35 || $0 == 63
        }) else { throw AssetResolutionFailure(.invalidReference, address: address) }
        var start = bytes.startIndex, cursor = start
        while true {
            try work.charge(0, address: address)
            if cursor == bytes.endIndex || bytes[cursor] == 47 {
                let segment = bytes[start..<cursor]
                guard !segment.isEmpty, !(segment.count == 1 && segment.first == 46),
                      !(segment.count == 2 && segment.allSatisfy({ $0 == 46 })) else {
                    throw AssetResolutionFailure(.invalidReference, address: address)
                }
                if cursor == bytes.endIndex { break }
                start = bytes.index(after: cursor)
            }
            cursor = bytes.index(after: cursor)
        }
    }
    static func metadata(_ asset: NativeInlineAsset, address: AssetAddress,
                         work: inout AssetResolutionWork) throws(AssetResolutionFailure) {
        try work.text(asset.key, address: address); try work.text(asset.format, address: address)
        try work.text(asset.provenance.source, address: address)
        guard !asset.key.isEmpty, !asset.format.isEmpty, !asset.provenance.source.isEmpty,
              asset.key.utf8.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw AssetResolutionFailure(.invalidInput, address: address)
        }
        try work.limit(asset.bytes.count, maximum: work.policy.maximumAssetBytes, resource: .assetBytes, address: address)
    }
    static func same(_ a: String, _ b: String, work: inout AssetResolutionWork, address: AssetAddress? = nil) throws(AssetResolutionFailure) -> Bool {
        try work.charge(a.utf8.count, address: address); try work.charge(b.utf8.count, address: address)
        return a.utf8.elementsEqual(b.utf8)
    }
    static func same(_ a: AssetAddress, _ b: AssetAddress, work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> Bool {
        try work.charge(1, address: b)
        if try !same(a.base, b.base, work: &work, address: b) { return false }
        return try same(a.relativePath, b.relativePath, work: &work, address: b)
    }
    static func index(_ address: AssetAddress, inventory: [AssetRequest], work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> Int {
        for index in inventory.indices {
            if try same(inventory[index].address, address, work: &work) { return index }
        }
        throw AssetResolutionFailure(.missingDeclaration, address: address)
    }
}
