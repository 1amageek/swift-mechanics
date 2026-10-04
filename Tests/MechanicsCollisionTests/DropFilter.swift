import SwiftMechanics

struct DropFilter: CollisionUserFiltering {
    func decide(first:CollisionProxy,second:CollisionProxy,remainingOperations:Int) throws(CollisionError) -> CollisionUserFilterResult {
        CollisionUserFilterResult(allowed:false,operations:1)
    }
}
