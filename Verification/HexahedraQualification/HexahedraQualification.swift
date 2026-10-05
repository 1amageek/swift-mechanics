#if canImport(HexahedraQualificationSupport)
import HexahedraQualificationSupport
#endif

@main
struct HexahedraQualification {
    static func main() throws {
        let qualification: any HexahedraQualifying=HexahedraQualificationCases()
        for selected in HexahedraQualificationCase.allCases {
            try qualification.run(selected)
            print("Hexahedra public case passed: \(selected.label)")
        }
    }
}
