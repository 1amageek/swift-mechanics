#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif
#if canImport(TimeParameterizationQualificationSupport)
import TimeParameterizationQualificationSupport
#endif

@main struct TimeParameterizationQualification {
    static func main() {
        var label = "original coupled physical tree"
        do throws(TimeParameterizationQualificationError) {
            label = "original coupled physical tree"
            try TimeParameterizationQualificationCases.originalCoupledPhysicalTree()
            print("PASS: " + label)
            label = "original analytic duration and signed extrema"
            try TimeParameterizationQualificationCases.originalAnalyticDurationAndSignedExtrema()
            print("PASS: " + label)
            label = "original waypoints clock and identity"
            try TimeParameterizationQualificationCases.originalWaypointsClockAndIdentity()
            print("PASS: " + label)
            label = "original static and signed motion infeasibility"
            try TimeParameterizationQualificationCases.originalStaticAndSignedMotionInfeasibility()
            print("PASS: " + label)
            label = "original domains shapes and revisions"
            try TimeParameterizationQualificationCases.originalDomainsShapesAndRevisions()
            print("PASS: " + label)
            label = "original work capacity and cancellation"
            try TimeParameterizationQualificationCases.originalWorkCapacityAndCancellation()
            print("PASS: " + label)
            label = "original arithmetic and duration failures"
            try TimeParameterizationQualificationCases.originalArithmeticAndDurationFailures()
            print("PASS: " + label)
        } catch {
            print("FAIL: " + label)
            exit(1)
        }
        print("PASS: seven original TimeParameterization public cases")
    }
}
