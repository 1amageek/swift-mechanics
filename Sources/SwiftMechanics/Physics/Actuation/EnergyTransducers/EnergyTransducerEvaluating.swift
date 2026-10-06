public protocol EnergyTransducerEvaluating: Sendable {
    func evaluate(position: Double, electricalState: Double, work: inout ActuationWork)
        throws(ActuationError) -> ElectromechanicalEnergySample
}
