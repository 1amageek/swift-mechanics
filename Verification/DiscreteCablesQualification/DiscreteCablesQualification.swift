import SwiftMechanics
#if canImport(DiscreteCablesQualificationSupport)
import DiscreteCablesQualificationSupport
#endif

@main
struct DiscreteCablesQualification {
    static func main() throws {
        let qualification: any DiscreteCablesQualifying = DiscreteCablesQualificationCases()
        for selected in DiscreteCablesQualificationCase.allCases {
            try qualification.run(selected)
            print("PASS "+selected.rawValue)
        }
    }
}
