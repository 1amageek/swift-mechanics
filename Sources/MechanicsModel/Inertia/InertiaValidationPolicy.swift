import MechanicsCore

public struct InertiaValidationPolicy: Equatable, Sendable {
    public let symmetry: NumericalTolerance
    public let physicalityRelative: Double

    public init(symmetry: NumericalTolerance, physicalityRelative: Double) throws(ModelError) {
        guard physicalityRelative.isFinite, physicalityRelative >= 0, physicalityRelative < 1 else {
            throw .invalidInertiaPolicy
        }
        self.symmetry = symmetry
        self.physicalityRelative = physicalityRelative
    }
}
