import SpatialProjectionQualificationSupport

@main struct SpatialProjectionQualification {
    static func main() throws {
        guard #available(macOS 15.0, *) else { throw SpatialProjectionQualificationError.unsupportedOperatingSystem }
        try SpatialProjectionQualificationCases.potentialSolenoidalProjection();print("SpatialProjection potential and solenoidal projection passed")
        try SpatialProjectionQualificationCases.originalPressureEquation();print("SpatialProjection original pressure equation passed")
        try SpatialProjectionQualificationCases.thirdAxisShear();print("SpatialProjection third-axis shear passed")
        try SpatialProjectionQualificationCases.donorMomentumEnergy();print("SpatialProjection donor momentum and energy passed")
        try SpatialProjectionQualificationCases.uniformSourceEvolution();print("SpatialProjection uniform source evolution passed")
        try SpatialProjectionQualificationCases.domainAndSupplierRefusals();print("SpatialProjection domain and supplier refusals passed")
        try SpatialProjectionQualificationCases.workAndCancellation();print("SpatialProjection work and cancellation passed")
    }
}
