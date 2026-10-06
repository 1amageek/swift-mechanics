public protocol AssetCatalogReading: Sendable {
    func nativeAssets(work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> [NativeInlineAsset]
    func asset(address: AssetAddress, work: inout AssetResolutionWork) throws(AssetResolutionFailure) -> AssetProviderRecord
}
