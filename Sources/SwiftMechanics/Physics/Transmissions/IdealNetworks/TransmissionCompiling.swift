
public protocol TransmissionCompiling: Sendable {
    func compile(id: UInt64, layout: ConstraintCoordinateLayout, ports: [TransmissionPortBinding], relations: [TransmissionRelation],
                 minimumPosition: [Double], maximumPosition: [Double], minimumTime: Double, maximumTime: Double,
                 policy: TransmissionPolicy, work: inout NumericalWork) throws(TransmissionError) -> CompiledTransmissionNetwork
}
