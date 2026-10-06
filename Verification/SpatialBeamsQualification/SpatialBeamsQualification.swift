#if canImport(SpatialBeamsQualificationSupport)
import SpatialBeamsQualificationSupport
#endif

@main
struct SpatialBeamsQualification {
    static func main() throws {
        if #available(macOS 15.0, *) {
            let suite: any SpatialBeamsQualifying = SpatialBeamsQualificationCases()
            for selected in SpatialBeamsQualificationCase.allCases {
                try suite.run(selected)
                print("SpatialBeams public case passed: " + selected.label)
            }
        } else {
            throw SpatialBeamsQualificationError.unsupportedNativePlatform
        }
    }
}
