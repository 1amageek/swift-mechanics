import SwiftMechanics
#if canImport(AssetResolutionQualificationSupport)
import AssetResolutionQualificationSupport
#endif
import Testing

@Suite(.timeLimit(.minutes(1)))
struct AssetResolutionQualificationTests {
    @Test func independentOriginalProviderAndPrefixWork() throws { try AssetResolutionQualificationCases.originalProviderAndExactWork() }
    @Test func originalDiamondAndPublicNativeCatalog() throws { try AssetResolutionQualificationCases.diamondAndNativeCatalog() }
    @Test func exactMetadataBytesAndDependencyOrderRefusals() throws { try AssetResolutionQualificationCases.dependencyAndMetadataRefusals() }
    @Test func graphReferenceCycleDepthAndDuplicates() throws { try AssetResolutionQualificationCases.graphAdmissionRefusals() }
    @Test func originalExactWorkAndCapacityBoundaries() throws { try AssetResolutionQualificationCases.exactResolutionWorkAndBoundaries() }
    @Test func actualProviderPrefixAndTighterCatalogCaps() throws { try AssetResolutionQualificationCases.providerAndCatalogLimits() }
    @Test func publicCheckedArithmeticRetainsCounters() throws { try AssetResolutionQualificationCases.checkedLedgerArithmetic() }
    @Test func actualTaskCancellationIsAwaited() async throws {
        let task = Task { () throws -> Void in
            withUnsafeCurrentTask { $0?.cancel() }
            try AssetResolutionQualificationCases.cancelledTask()
        }
        try await task.value
    }
}
