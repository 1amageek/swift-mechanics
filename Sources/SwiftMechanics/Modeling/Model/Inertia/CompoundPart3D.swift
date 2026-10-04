
public struct CompoundPart3D: Equatable, Sendable {
    public let primitive: AnalyticPrimitive3D
    public let density: Double
    public let primitiveToCompound: RigidTransform

    public init(primitive: AnalyticPrimitive3D, density: Double, primitiveToCompound: RigidTransform) throws(ModelError) {
        try primitive.validating()
        guard density.isFinite, density > 0 else { throw .invalidDensity }
        self.primitive = primitive
        self.density = density
        self.primitiveToCompound = primitiveToCompound
    }
}
