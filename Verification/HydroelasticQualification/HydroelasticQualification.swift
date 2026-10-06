#if canImport(HydroelasticQualificationSupport)
import HydroelasticQualificationSupport
#endif

@main
struct HydroelasticQualification {
    static func main() throws {
        let qualification: any HydroelasticQualifying = HydroelasticQualificationCases()
        for selected in HydroelasticQualificationCase.allCases {
            try qualification.run(selected)
            print("Hydroelastic public case passed: \(selected.label)")
        }
    }
}
