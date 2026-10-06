import SwiftMechanics
#if canImport(HeightfieldsQualificationSupport)
import HeightfieldsQualificationSupport
#endif

@main
struct HeightfieldsQualification {
    static func main() throws {
        try HeightfieldsQualificationCases.flatOriginalFeatures()
        print("PASS flat original features")
        try HeightfieldsQualificationCases.slopeAndTransform()
        print("PASS slope and transform")
        try HeightfieldsQualificationCases.diagonalsAndRayOrder()
        print("PASS diagonals and ray order")
        try HeightfieldsQualificationCases.rayRejectionsAndAmbiguity()
        print("PASS bounded ray rejection and ambiguity")
        try HeightfieldsQualificationCases.sphereClearanceAndQuality()
        print("PASS sphere clearance and quality")
        try HeightfieldsQualificationCases.refitOriginalLifetime()
        print("PASS refit original lifetime")
        try HeightfieldsQualificationCases.admissionAndResourceRefusals()
        print("PASS admission and resource refusals")
    }
}
