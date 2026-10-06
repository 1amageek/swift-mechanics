import GeometryParametersQualificationSupport

@main
struct GeometryParametersQualification {
    static func main() throws {
        try GeometryParametersQualificationCases.rootTranslation()
        print("GeometryParameters literal SI root translation passed")
        try GeometryParametersQualificationCases.rootRotation()
        print("GeometryParameters right-body root rotation and moving bias passed")
        try GeometryParametersQualificationCases.parentAnchor()
        print("GeometryParameters nonidentity parent anchor passed")
        try GeometryParametersQualificationCases.childAnchor()
        print("GeometryParameters inverse child anchor passed")
        try GeometryParametersQualificationCases.rawAxes()
        print("GeometryParameters normalized revolute/prismatic/screw axes passed")
        try GeometryParametersQualificationCases.sourceRefusals()
        print("GeometryParameters source/chart/units/shape refusals passed")
        try GeometryParametersQualificationCases.exactWorkAndCancellation()
        print("GeometryParameters exact work and caller cancellation passed")
        try GeometryParametersQualificationCases.domainsAndSupplierFailure()
        print("GeometryParameters declared domain and actual supplier failure passed")
        print("GeometryParameters eight selected synchronous public cases completed")
    }
}
