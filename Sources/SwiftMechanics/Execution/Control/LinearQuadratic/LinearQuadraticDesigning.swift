public protocol LinearQuadraticDesigning: Sendable {
    func design(_ system: DiscreteControlSystem, stateCost: [Double], inputCost: [Double], stabilizingGainWitness: [Double],
                policy: LinearQuadraticPolicy, work: inout NumericalWork) throws(LinearQuadraticFailure) -> LinearQuadraticDesign
}
