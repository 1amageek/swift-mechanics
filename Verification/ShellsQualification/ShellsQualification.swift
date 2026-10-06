#if canImport(ShellsQualificationSupport)
import ShellsQualificationSupport
#endif

@main
struct ShellsQualification {
    static func main() throws {
        guard #available(macOS 15.0, *) else { throw ShellsQualificationError.unsupportedNativePlatform }
        let suite: any ShellsQualifying = ShellsQualificationCases()
        for selected in ShellsQualificationCase.allCases {
            try suite.run(selected)
            print("Shells public case passed: " + selected.label)
        }
    }
}
