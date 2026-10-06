import InertialParametersQualificationSupport

@main
struct InertialParametersQualification {
    static func main() throws {
        try InertialParametersQualificationCases.tenCoordinateOriginLaws()
        print("InertialParameters ten-coordinate literal origin laws passed")
        try InertialParametersQualificationCases.uniformGravityAndPower()
        print("InertialParameters uniform gravity and actual power passed")
        try InertialParametersQualificationCases.rotatedCoupledDifferences()
        print("InertialParameters rotated coupled original differences passed")
        try InertialParametersQualificationCases.forwardAccelerationAndRoundtrip()
        print("InertialParameters original forward acceleration and roundtrip passed")
        try InertialParametersQualificationCases.sourceAndMappingRefusals()
        print("InertialParameters source identity and mapping refusals passed")
        try InertialParametersQualificationCases.physicalAndRankDomains()
        print("InertialParameters physical neighborhood and original rank refusals passed")
        try InertialParametersQualificationCases.cumulativeWorkBounds()
        print("InertialParameters exact cumulative numerical and supplier work passed")
        try InertialParametersQualificationCases.callerAndPublicationCancellation()
        print("InertialParameters caller and final publication cancellation passed")
        print("InertialParameters eight selected synchronous public cases completed")
    }
}
