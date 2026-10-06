import AssetResolutionQualificationSupport

@main
struct AssetResolutionQualification {
    static func main() throws {
        try AssetResolutionQualificationCases.originalProviderAndExactWork()
        print("Asset original opaque bytes/provenance/exact provider prefix work witness passed")
        try AssetResolutionQualificationCases.diamondAndNativeCatalog()
        print("Asset original diamond/dependency order/read-once/public native catalog witness passed")
        try AssetResolutionQualificationCases.dependencyAndMetadataRefusals()
        print("Asset original bytes/metadata/dependency/Unicode exact refusal witness passed")
        try AssetResolutionQualificationCases.graphAdmissionRefusals()
        print("Asset graph missing/cycle/depth/duplicate/unsafe-reference witness passed")
        try AssetResolutionQualificationCases.exactResolutionWorkAndBoundaries()
        print("Asset independent exact cumulative work/capacity/publication boundary witness passed")
        try AssetResolutionQualificationCases.providerAndCatalogLimits()
        print("Asset actual failed source prefix/transactional catalog/current caps witness passed")
        try AssetResolutionQualificationCases.checkedLedgerArithmetic()
        print("Asset public checked ledger arithmetic witness passed")
        print("Asset selected synchronous public qualification completed")
    }
}
