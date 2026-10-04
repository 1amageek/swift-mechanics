public struct DynamicsCapacity: Equatable, Sendable {
    public let maximumBodies: Int
    public let maximumVelocities: Int
    public let maximumBodyWrenches: Int
    public let maximumGeneralizedContributions: Int
    public init(maximumBodies: Int, maximumVelocities: Int, maximumBodyWrenches: Int,
                maximumGeneralizedContributions: Int) throws(DynamicsError) {
        guard maximumBodies >= 0, maximumVelocities >= 0, maximumBodyWrenches >= 0,
              maximumGeneralizedContributions >= 0 else { throw .invalidInput }
        self.maximumBodies = maximumBodies; self.maximumVelocities = maximumVelocities
        self.maximumBodyWrenches = maximumBodyWrenches; self.maximumGeneralizedContributions = maximumGeneralizedContributions
    }
}
