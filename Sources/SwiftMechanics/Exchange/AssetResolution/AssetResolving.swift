public protocol AssetResolving: Sendable {
    func resolve(roots: [AssetAddress], inventory: [AssetRequest], work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> AssetResolvedCatalog
}
