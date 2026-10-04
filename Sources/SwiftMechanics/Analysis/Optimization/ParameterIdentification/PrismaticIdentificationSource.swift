public struct PrismaticIdentificationSource: Sendable {
    public let tree: KinematicTree
    public let referenceInertias: [RigidBodyInertia]
    public let body: ModelReference
    public let massParameterID: UInt64
    public let dampingParameterID: UInt64
    public let dashpotRestCoordinate: Double
    public let maximumDisplacement: Double
    public let maximumRate: Double
    public init(tree: KinematicTree, referenceInertias: [RigidBodyInertia], body: ModelReference,
                massParameterID: UInt64, dampingParameterID: UInt64, dashpotRestCoordinate: Double,
                maximumDisplacement: Double, maximumRate: Double) {
        self.tree=tree; self.referenceInertias=referenceInertias; self.body=body
        self.massParameterID=massParameterID; self.dampingParameterID=dampingParameterID
        self.dashpotRestCoordinate=dashpotRestCoordinate; self.maximumDisplacement=maximumDisplacement; self.maximumRate=maximumRate
    }
}
