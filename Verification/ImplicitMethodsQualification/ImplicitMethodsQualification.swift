#if canImport(ImplicitMethodsQualificationSupport)
import ImplicitMethodsQualificationSupport
#endif

@main
enum ImplicitMethodsQualification {
    static func main() throws {
        guard #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, *) else {
            throw ImplicitMethodsQualificationError.unsupportedPlatform
        }
        try ImplicitMethodsQualificationCases.eulerPhysicalEndpointAndEnergy(); print("PASS eulerPhysicalEndpointAndEnergy")
        try ImplicitMethodsQualificationCases.eulerOrderAndRepeat(); print("PASS eulerOrderAndRepeat")
        try ImplicitMethodsQualificationCases.generalizedAlphaEndpoints(); print("PASS generalizedAlphaEndpoints")
        try ImplicitMethodsQualificationCases.hhtOriginalEndpointsAndEnergy(); print("PASS hhtOriginalEndpointsAndEnergy")
        try ImplicitMethodsQualificationCases.providerRefusalAndRollback(); print("PASS providerRefusalAndRollback")
        try ImplicitMethodsQualificationCases.domainAndExclusiveOwner(); print("PASS domainAndExclusiveOwner")
        try ImplicitMethodsQualificationCases.budgetsAndCallbackCancellation(); print("PASS budgetsAndCallbackCancellation")
        print("ImplicitMethods original seven public cases complete.")
    }
}
