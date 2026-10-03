public struct CollisionFilterPolicy: Sendable {
    public let jointExclusions: [CollisionPairKey]
    public let allowSameBody: Bool
    public let user: (any CollisionUserFiltering)?

    public init(jointExclusions: [CollisionPairKey], allowSameBody: Bool, user: (any CollisionUserFiltering)?) {
        self.jointExclusions = jointExclusions; self.allowSameBody = allowSameBody; self.user = user
    }
}
