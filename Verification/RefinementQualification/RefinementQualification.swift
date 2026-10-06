#if canImport(RefinementQualificationSupport)
import RefinementQualificationSupport
#endif

@main
struct RefinementQualification {
    static func main() throws {
        let qualification: any RefinementQualifying=RefinementQualificationCases()
        for selected in RefinementQualificationCase.allCases {
            try qualification.run(selected)
            print("Refinement public case passed: "+selected.label)
        }
    }
}
