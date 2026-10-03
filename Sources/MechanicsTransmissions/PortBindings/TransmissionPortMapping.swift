import MechanicsConstraints
import MechanicsNumerics

public protocol TransmissionPortMapping: Sendable {
    func map(_ ports: [TransmissionPortBinding],layout: ConstraintCoordinateLayout,efforts: [Double],velocity: [Double],
             policy: TransmissionPolicy,work: inout NumericalWork) throws(TransmissionError) -> MappedTransmissionPorts
}
