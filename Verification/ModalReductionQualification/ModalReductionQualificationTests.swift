import Testing
import ModalReductionQualificationSupport
@Suite(.timeLimit(.minutes(1)))
struct ModalReductionQualificationTests {
    @Test(arguments: ModalReductionQualificationCase.allCases)
    func originalPublicCase(_ selected: ModalReductionQualificationCase) throws {
        guard #available(macOS 15.0, *) else {
            throw ModalReductionQualificationError.unsupportedOperatingSystem(requiredMacOSMajor: 15)
        }
        let suite: any ModalReductionQualifying = ModalReductionQualificationCases()
        try suite.run(selected)
    }
    @Test func awaitedTaskCancellation() async throws {
        guard #available(macOS 15.0, *) else {
            throw ModalReductionQualificationError.unsupportedOperatingSystem(requiredMacOSMajor: 15)
        }
        try await ModalReductionQualificationCases().awaitedTaskCancellation()
    }
}
