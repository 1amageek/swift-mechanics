public protocol DiscreteControlSystemPreparing: Sendable {
    func analytic(identity: String, samplePeriodSeconds: Double, stateDimensions: [PhysicalDimension], inputDimensions: [PhysicalDimension],
                  stateScales: [Double], inputScales: [Double], stateMatrix: [Double], inputMatrix: [Double],
                  policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> DiscreteControlSystem
    func bilinear(_ source: EquilibriumLinearization, identity: String, samplePeriodSeconds: Double, stateScales: [Double],
                  inputDimension: PhysicalDimension, inputScale: Double, parameterChangePerInputUnit: Double,
                  policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> DiscreteControlSystem
}
