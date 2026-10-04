public struct MechanicalDirection: Sendable {
    public let tree: TreeDirection
    public let inertias: [BodyInertiaDirection]
    public let gravity: Vector3
    public let bodyWrenches: [BodyWrenchDirection]
    public let generalizedForces: [[Double]]
    public let drive: [Double]
    public let parameters: [Double]
    public init(tree: TreeDirection, inertias: [BodyInertiaDirection], gravity: Vector3 = .zero,
                bodyWrenches: [BodyWrenchDirection] = [], generalizedForces: [[Double]] = [], drive: [Double], parameters: [Double] = []) {
        self.tree=tree; self.inertias=inertias; self.gravity=gravity; self.bodyWrenches=bodyWrenches
        self.generalizedForces=generalizedForces; self.drive=drive; self.parameters=parameters
    }
}
