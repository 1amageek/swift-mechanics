internal final class ConstrainedImpactWorkspace: Sendable {
    let source: PreparedConstrainedImpact
    let inverseRows: [Double]
    let schur: [Double]
    let reserved: Int
    var count: Int { source.retainedRowIDs.count+1 }
    var velocityCount: Int { source.impact.system.velocityCount }
    init(source: PreparedConstrainedImpact, inverse: [Double], schur: [Double], reserved: Int) {
        self.source = source; inverseRows = inverse; self.schur = schur; self.reserved = reserved
    }
}
