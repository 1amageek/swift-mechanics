import MechanicsConstraints

public struct CompiledTransmissionNetwork: Sendable {
    public let id: UInt64
    public let modelRevision: UInt64
    public let ports: [TransmissionPortBinding]
    public let physicalRows: [PhysicalTransmissionRow]
    public let equations: QuadraticConstraintSystem
    internal init(id: UInt64, modelRevision: UInt64, ports: [TransmissionPortBinding], physicalRows: [PhysicalTransmissionRow], equations: QuadraticConstraintSystem) {
        self.id=id; self.modelRevision=modelRevision; self.ports=ports; self.physicalRows=physicalRows; self.equations=equations
    }
}
