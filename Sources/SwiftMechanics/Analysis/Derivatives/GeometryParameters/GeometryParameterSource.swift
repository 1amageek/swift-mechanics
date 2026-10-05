public struct GeometryParameterSource: Sendable {
    public let modelSource: SourceProvenance
    public let tree: KinematicTree
    public let state: KinematicState
    public let bindings: [GeometryParameterBinding]
    public init(modelSource: SourceProvenance, tree: KinematicTree, state: KinematicState, bindings: [GeometryParameterBinding]) {
        self.modelSource = modelSource; self.tree = tree; self.state = state; self.bindings = bindings
    }
}
