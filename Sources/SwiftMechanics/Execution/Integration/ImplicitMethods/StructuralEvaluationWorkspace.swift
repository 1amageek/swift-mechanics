struct StructuralEvaluationWorkspace: Sendable {
    var displacement: [Double]
    var velocity: [Double]
    var acceleration: [Double]
    var residual: [Double]
    var secondaryResidual: [Double]
    var tangent: [Double]
    var secondaryTangent: [Double]
    init(count: Int, entries: Int) {
        displacement = [Double](repeating: .nan, count: count)
        velocity = [Double](repeating: .nan, count: count)
        acceleration = [Double](repeating: .nan, count: count)
        residual = [Double](repeating: .nan, count: count)
        secondaryResidual = [Double](repeating: .nan, count: count)
        tangent = [Double](repeating: .nan, count: entries)
        secondaryTangent = [Double](repeating: .nan, count: entries)
    }
}
