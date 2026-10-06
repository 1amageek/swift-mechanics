/// Exclusively owned scalar-joint ABA storage; no target-specific or shared mutable state.
internal struct ArticulatedWorkspace {
    var parents: [Int]
    var coordinates: [Int]
    var inertia: [Double]
    var transport: [Double]
    var subspace: [Double]
    var bias: [Double]
    var forceBias: [Double]
    var projectedInertia: [Double]
    var bodyAcceleration: [Double]
    var pivots: [Double]
    var efforts: [Double]
    var generalizedEffort: [Double]
    init(bodies: Int, velocities: Int) {
        parents = [Int](repeating:0,count:bodies); coordinates = [Int](repeating:-1,count:bodies)
        inertia = [Double](repeating:0,count:36*bodies); transport = inertia
        subspace = [Double](repeating:0,count:6*bodies); bias = subspace; forceBias = subspace
        projectedInertia = subspace; bodyAcceleration = subspace
        pivots = [Double](repeating:0,count:bodies); efforts = pivots
        generalizedEffort = [Double](repeating:0,count:velocities)
    }
}
