import Testing
#if canImport(SpatialProjectionQualificationSupport)
import SpatialProjectionQualificationSupport
#endif

@Suite struct SpatialProjectionQualificationTests {
    @Test func actualPotentialSolenoidalProjection() throws { try SpatialProjectionQualificationCases.potentialSolenoidalProjection() }
    @Test func actualOriginalPressureEquation() throws { try SpatialProjectionQualificationCases.originalPressureEquation() }
    @Test func actualThirdAxisShear() throws { try SpatialProjectionQualificationCases.thirdAxisShear() }
    @Test func actualDonorMomentumEnergy() throws { try SpatialProjectionQualificationCases.donorMomentumEnergy() }
    @Test func actualUniformSourceEvolution() throws { try SpatialProjectionQualificationCases.uniformSourceEvolution() }
    @Test func actualDomainAndSupplierRefusals() throws { try SpatialProjectionQualificationCases.domainAndSupplierRefusals() }
    @Test func actualWorkAndCancellation() throws {
        guard #available(macOS 15.0, *) else { throw SpatialProjectionQualificationError.unsupportedOperatingSystem }
        try SpatialProjectionQualificationCases.workAndCancellation()
    }
    @Test func actualNativeTaskCancellation() async throws { try await SpatialProjectionQualificationCases.nativeTaskCancellation() }
}
