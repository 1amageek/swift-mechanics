import JointStopsQualificationSupport

@main
struct JointStopsQualification {
    static func main() throws {
        try JointStopQualificationCases.coupledLowerBoundary()
        print("JointStops original coupled mass, post encoder, momentum, energy and impulse work witness passed")
        try JointStopQualificationCases.upperElasticAndLowerPlastic()
        print("JointStops signed upper elastic and lower plastic boundary witness passed")
        try JointStopQualificationCases.rotaryMetricAndThreshold()
        print("JointStops rotary SI metric, conjugate impulse and threshold restitution witness passed")
        try JointStopQualificationCases.signedBoundaryRefusals()
        try JointStopQualificationCases.sourceUnitAndUnsupportedRefusals()
        print("JointStops boundary, source, SI and unsupported-domain typed refusal witnesses passed")
        try JointStopQualificationCases.boundedWorkAndCancellation()
        try JointStopQualificationCases.supplierFailureAndLedger()
        print("JointStops bounded work, supplied cancellation and original supplier failure ledger witnesses passed")
        print("JointStops selected synchronous public cases completed")
    }
}
