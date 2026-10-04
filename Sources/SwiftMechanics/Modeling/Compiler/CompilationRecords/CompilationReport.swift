public struct CompilationReport: Equatable, Sendable {
    public let bodyCount: Int
    public let frameCount: Int
    public let jointCount: Int
    public let extensionCount: Int
    public let positionCount: Int
    public let velocityCount: Int
    public let structuralTreeRank: StructuralTreeRank
    public let selectedEquations: [CompiledEquation]

    internal init(bodyCount: Int, frameCount: Int, jointCount: Int, extensionCount: Int, positionCount: Int,
                  velocityCount: Int, structuralTreeRank: StructuralTreeRank) {
        self.bodyCount = bodyCount; self.frameCount = frameCount; self.jointCount = jointCount; self.extensionCount = extensionCount
        self.positionCount = positionCount; self.velocityCount = velocityCount; self.structuralTreeRank = structuralTreeRank
        selectedEquations = [.treeAnchorComposition, .coordinateRateMapping, .geometricVelocityWithPrescribedDrift, .accelerationWithBias]
    }
}
