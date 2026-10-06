import SwiftMechanics
#if canImport(CoSimulationQualificationSupport)
import CoSimulationQualificationSupport
#endif

@main
struct CoSimulationQualification {
    static func main() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            throw CoSimulationQualificationError.unsupportedPlatform
        }
        let qualification:any CoSimulationQualifying=CoSimulationQualificationCases()
        for selected in CoSimulationQualificationCase.allCases {
            try qualification.run(selected)
            print("PASS " + selected.rawValue)
        }
    }
}
