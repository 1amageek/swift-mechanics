public enum AssetResource: Equatable, Sendable {
    case roots, references, edges, depth, stringBytes, metadataBytes, assetBytes, totalBytes, storageBytes, operations
    case providerInventory, providerReads, providerBytes, providerOperations
}
