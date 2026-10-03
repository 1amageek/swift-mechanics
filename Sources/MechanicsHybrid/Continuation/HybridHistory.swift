import MechanicsJoints

public struct HybridHistory: Sendable {
    public let acceptedTime: Double
    public let acceptedPosition: [Double]
    public let acceptedVelocity: [Double]
    public let impactGroups: UInt64
    public let lastImpactTime: Double?
    public let lastEventIDs: [UInt64]
    internal let binding: [UInt8]
    internal init(binding: [UInt8], time: Double, q: [Double], v: [Double], groups: UInt64, lastTime: Double?, ids: [UInt64]) {
        self.binding=binding; acceptedTime=time; acceptedPosition=q; acceptedVelocity=v
        impactGroups=groups; lastImpactTime=lastTime; lastEventIDs=ids
    }
}
