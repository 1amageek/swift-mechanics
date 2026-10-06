/// Executable producer outputs retain their source declarations alongside actual model bindings.
public struct StructuralMechanicalSystem: Sendable {
    public let source: StructuralPhysicsDraft
    public let model: CompiledMechanicalModel
    public let coordinateBindings: [StructuralCoordinateBinding]
    public let layout: ConstraintCoordinateLayout
    public let transmission: CompiledTransmissionNetwork?
    public let passiveCatalog: StationaryLoadCatalog?
    public let passiveSelection: StationaryLoadSelection?
    public let motors: [StructuralMotorBinding]
    public let drive: [Double]
    internal init(source: StructuralPhysicsDraft, model: CompiledMechanicalModel,
        coordinateBindings: [StructuralCoordinateBinding], layout: ConstraintCoordinateLayout,
        transmission: CompiledTransmissionNetwork?, passiveCatalog: StationaryLoadCatalog?,
        passiveSelection: StationaryLoadSelection?, motors: [StructuralMotorBinding], drive: [Double]) {
        self.source = source; self.model = model; self.coordinateBindings = coordinateBindings
        self.layout = layout; self.transmission = transmission; self.passiveCatalog = passiveCatalog
        self.passiveSelection = passiveSelection; self.motors = motors; self.drive = drive
    }
}
