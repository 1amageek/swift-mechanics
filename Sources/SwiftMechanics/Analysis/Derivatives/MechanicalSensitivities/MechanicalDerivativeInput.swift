public struct MechanicalDerivativeInput: Sendable {
    public let tree: KinematicTree
    public let state: KinematicState
    public let inertias: [RigidBodyInertia]
    public let gravity: AffineGravity?
    public let bodyWrenches: [BodyWrenchContribution]
    public let generalizedForces: [GeneralizedForceContribution]
    public let drive: [Double]
    public let forceProvider: (any DifferentiatedForceProviding)?
    public let parameters: [Double]
    public let parameterIDs: [UInt64]
    public let parameterDimensions: [PhysicalDimension]
    public init(tree: KinematicTree, state: KinematicState, inertias: [RigidBodyInertia], gravity: AffineGravity?,
                bodyWrenches: [BodyWrenchContribution] = [], generalizedForces: [GeneralizedForceContribution] = [], drive: [Double],
                forceProvider: (any DifferentiatedForceProviding)? = nil, parameters: [Double] = [], parameterIDs: [UInt64] = [],
                parameterDimensions: [PhysicalDimension] = []) {
        self.tree=tree; self.state=state; self.inertias=inertias; self.gravity=gravity
        self.bodyWrenches=bodyWrenches; self.generalizedForces=generalizedForces; self.drive=drive; self.forceProvider=forceProvider
        self.parameters=parameters; self.parameterIDs=parameterIDs; self.parameterDimensions=parameterDimensions
    }
}
