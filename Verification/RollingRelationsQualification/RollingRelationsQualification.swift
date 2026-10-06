#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(WASILibc)
import WASILibc
#endif
#if canImport(RollingRelationsQualificationSupport)
import RollingRelationsQualificationSupport
#endif

@main struct RollingRelationsQualification {
    static func main() {
        var label = "straight disk"
        do throws(RollingRelationsQualificationError) {
            try RollingRelationsQualificationCases.straightDisk(); print("PASS: "+label)
            label = "camber projection"; try RollingRelationsQualificationCases.camberProjection(); print("PASS: "+label)
            label = "moving plane and power"; try RollingRelationsQualificationCases.movingPlaneAndPower(); print("PASS: "+label)
            label = "contact first derivative"; try RollingRelationsQualificationCases.contactFirstDerivative(); print("PASS: "+label)
            label = "source and contact refusals"; try RollingRelationsQualificationCases.sourceAndContactRefusals(); print("PASS: "+label)
            label = "rank and work bounds"; try RollingRelationsQualificationCases.rankAndWorkBounds(); print("PASS: "+label)
            label = "policy and cancellation"; try RollingRelationsQualificationCases.policyAndCancellation(); print("PASS: "+label)
        } catch {
            print("FAIL: "+label); exit(1)
        }
        print("PASS: seven original RollingRelations public cases")
    }
}
