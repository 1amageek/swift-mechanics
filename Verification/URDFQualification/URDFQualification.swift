import URDFQualificationSupport

@main
struct URDFQualification {
    static func main() throws {
        try URDFQualificationCases.rotatedInertiaAndMotion()
        print("URDF original rotated full inertia and actual joint motion passed")
        try URDFQualificationCases.actualRigidEquations()
        print("URDF actual rigid equations and independent force/energy oracles passed")
        try URDFQualificationCases.movingAnalyticCollision()
        print("URDF actual moving analytic collision witness passed")
        try URDFQualificationCases.rootVariantsAndUnavailableDynamics()
        print("URDF SI root variants and unavailable dynamics refusals passed")
        try URDFQualificationCases.originalExportAndLosses()
        print("URDF independent original export and explicit representation losses passed")
        try URDFQualificationCases.semanticRefusals()
        print("URDF original typed semantic and law refusals passed")
        try URDFQualificationCases.capacitiesAndReceipts()
        print("URDF actual bounded work and retained receipts passed")
    }
}
