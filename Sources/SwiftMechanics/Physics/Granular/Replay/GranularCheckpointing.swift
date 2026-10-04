public protocol GranularCheckpointing: Sendable {
    func capture(_ state: GranularState, policy: GranularPolicy, work: inout NumericalWork) throws(GranularError) -> GranularCheckpoint
    func restore(_ checkpoint: GranularCheckpoint, model: GranularModel, policy: GranularPolicy, work: inout NumericalWork) throws(GranularError) -> GranularState
}
