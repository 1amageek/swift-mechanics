#if canImport(FieldOutputsQualificationSupport)
import FieldOutputsQualificationSupport
#endif

@main
struct FieldOutputsQualification {
    static func main() throws {
        let qualification: any FieldOutputsQualifying=FieldOutputsQualificationCases()
        for selected in FieldOutputsQualificationCase.allCases {
            try qualification.run(selected)
            print("FieldOutputs public case passed: \(selected.label)")
        }
    }
}
