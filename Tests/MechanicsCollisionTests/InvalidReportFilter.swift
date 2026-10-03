import MechanicsCollision

struct InvalidReportFilter: CollisionUserFiltering {
    func decide(first:CollisionProxy,second:CollisionProxy,remainingOperations:Int) throws(CollisionError) -> CollisionUserFilterResult {
        CollisionUserFilterResult(allowed:true,operations:0)
    }
}
