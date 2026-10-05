public struct ScalarControlPort: Sendable {
    public let binding: ActuatorBinding
    public let parentAnchorFrame: EntityID
    public let positionDimension = PhysicalDimension.length
    public let rateDimension = PhysicalDimension(length:1,time:-1)
    public let effortDimension = PhysicalDimension(length:1,mass:1,time:-2)
    public init(binding: ActuatorBinding, parentAnchorFrame: EntityID) throws(ControlFailure) {
        guard binding.coordinate == .translation, binding.authority == .dynamicState,
              binding.positionIndex == 0, binding.velocityIndex == 0, parentAnchorFrame.kind == .frame else {
            throw ControlFailure(.incompatiblePort,phase:"port")
        }
        self.binding=binding;self.parentAnchorFrame=parentAnchorFrame
    }
}
