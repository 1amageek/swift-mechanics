import FrictionalImpulseQualificationSupport

@main
struct FrictionalImpulseQualification {
    static func main() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            throw FrictionalImpulseQualificationError.platformUnavailable
        }
        let qualification: any FrictionalImpulseQualifying = FrictionalImpulseQualificationCases()
        for selected in FrictionalImpulseQualificationCase.allCases {
            try qualification.run(selected)
            print("FrictionalImpulse public case passed: " + selected.rawValue)
        }
    }
}
