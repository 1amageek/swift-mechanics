#if canImport(NonlinearEstimationQualificationSupport)
import NonlinearEstimationQualificationSupport
#endif
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif

// FIXME(INCOMPLETE_IMPLEMENTATION): This standalone entry runs the prepared shared EKF cases but has no matched-source Native or portable execution proof yet. It must not be reported qualified until the original seven success/refusal/work cases actually pass with preserved source/object/link identity.
@main
struct NonlinearEstimationQualification {
    static func main() {
        do {
            try NonlinearEstimationQualificationCases.originalMechanicsAndPhysicalJacobian()
            print("PASS: original nonlinear mechanical source and physical Jacobian")
            try NonlinearEstimationQualificationCases.originalRK4AndDiscreteTransition()
            print("PASS: original RK4 and discrete transition")
            try NonlinearEstimationQualificationCases.originalInnovationAndJoseph()
            print("PASS: original encoder innovation and Joseph covariance")
            try NonlinearEstimationQualificationCases.originalScaledCovariance()
            print("PASS: original explicit SI covariance scales")
            try NonlinearEstimationQualificationCases.originalTimeSourceAndDomain()
            print("PASS: original time source and physical domain refusals")
            try NonlinearEstimationQualificationCases.originalPSDAndCovariance()
            print("PASS: original zero-diagonal PSD and covariance admission")
            try NonlinearEstimationQualificationCases.originalWorkCapacityAndCancellation()
            print("PASS: original work capacity and cancellation")
            print("PASS: seven original NonlinearEstimation public cases")
        } catch {
            print("FAIL: original NonlinearEstimation qualification")
            exit(1)
        }
    }
}
