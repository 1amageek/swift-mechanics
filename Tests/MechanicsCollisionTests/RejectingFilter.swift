import SwiftMechanics

struct RejectingFilter: CollisionUserFiltering {
    func decide(first:CollisionProxy,second:CollisionProxy,remainingOperations:Int) throws(CollisionError) -> CollisionUserFilterResult {
        throw .invalidFilterReport
    }
}
