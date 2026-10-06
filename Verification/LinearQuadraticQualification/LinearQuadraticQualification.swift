import LinearQuadraticQualificationSupport

@main
struct LinearQuadraticQualification {
    static func main() throws {
        try LinearQuadraticQualificationCases.analyticScalarRoots()
        print("LinearQuadratic independent analytic scalar roots passed")
        try LinearQuadraticQualificationCases.diagonalMatrixEquations()
        print("LinearQuadratic diagonal original matrix and cost equations passed")
        try LinearQuadraticQualificationCases.mechanicalRealizationAndDynamics()
        print("LinearQuadratic actual mechanical realization and dynamics passed")
        try LinearQuadraticQualificationCases.unitsAndSaturation()
        print("LinearQuadratic physical units and disclosed saturation passed")
        try LinearQuadraticQualificationCases.sourceAndPortRefusals()
        print("LinearQuadratic source and physical port refusals passed")
        try LinearQuadraticQualificationCases.costAndStabilityRefusals()
        print("LinearQuadratic cost witness and original stability refusals passed")
        try LinearQuadraticQualificationCases.cumulativeWorkAndSupplierFailures()
        print("LinearQuadratic cumulative work and actual supplier failures passed")
        try LinearQuadraticQualificationCases.callerAndPublicationCancellation()
        print("LinearQuadratic caller and final publication cancellation passed")
        print("LinearQuadratic eight selected synchronous public cases completed")
        try LinearQuadraticCostBoundaryQualification.run()
        print("LinearQuadratic exact represented cost boundaries passed")
    }
}
