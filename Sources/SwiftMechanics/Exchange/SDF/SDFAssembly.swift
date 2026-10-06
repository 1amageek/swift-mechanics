public struct SDFAssembly: Sendable {
    public let scopedName: String
    public let model: CompiledMechanicalModel
    public let gravity: AffineGravity
}
