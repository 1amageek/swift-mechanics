public protocol LinearQuadraticFeedbackEvaluating: Sendable {
    func evaluate(_ design: LinearQuadraticDesign, systemIdentity: String, state: [Double], stateDimensions: [PhysicalDimension],
                  minimumInput: [Double], maximumInput: [Double], policy: LinearQuadraticPolicy,
                  work: inout NumericalWork) throws(LinearQuadraticFailure) -> LinearQuadraticCommand
    func scalarEffort(_ design: LinearQuadraticDesign, feedback: ScalarControlFeedback, sampleTimeSeconds: Double,
                      nominalEffortNewtons: Double, minimumEffortNewtons: Double, maximumEffortNewtons: Double,
                      policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> ScalarLinearQuadraticEffort
}
