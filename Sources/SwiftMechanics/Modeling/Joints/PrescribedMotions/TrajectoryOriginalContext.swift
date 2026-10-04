internal final class TrajectoryOriginalContext<Value:Sendable>: Sendable {
    let original:Value
    let reservedStorage:Int
    init(original:Value,reservedStorage:Int) { self.original=original;self.reservedStorage=reservedStorage }
}
