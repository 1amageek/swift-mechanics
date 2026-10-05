#if canImport(AttachmentsQualificationSupport)
import AttachmentsQualificationSupport
#endif

@main
struct AttachmentsQualification {
    static func main() throws {
        let qualification: any AttachmentsQualifying=AttachmentsQualificationCases()
        for selected in AttachmentsQualificationCase.allCases {
            try qualification.run(selected)
            print("Attachments public case passed: \(selected.label)")
        }
    }
}
