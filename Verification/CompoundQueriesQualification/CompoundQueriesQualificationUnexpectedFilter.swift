import SwiftMechanics

/// Any invocation contradicts the selected explicit compound refusal contract.
public struct CompoundQueriesQualificationUnexpectedFilter: CollisionUserFiltering, Sendable {
    public init() {}
    public func decide(first: CollisionProxy, second: CollisionProxy,
                       remainingOperations: Int) throws(CollisionError) -> CollisionUserFilterResult {
        throw .invalidFilterReport
    }
}
