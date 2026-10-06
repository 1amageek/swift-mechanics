import ModalReductionQualificationSupport
@main struct ModalReductionQualification {
    static func main() throws {
        guard #available(macOS 15.0, *) else {
            throw ModalReductionQualificationError.unsupportedOperatingSystem(requiredMacOSMajor: 15)
        }
        let suite: any ModalReductionQualifying = ModalReductionQualificationCases()
        for selected in ModalReductionQualificationCase.allCases {
            try suite.run(selected)
            print("PASS "+selected.label)
        }
    }
}
