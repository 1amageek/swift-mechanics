public protocol JointMotionEvaluating: Sendable {
    func evaluate(_ manifold: JointManifold, q: ArraySlice<Double>, v: ArraySlice<Double>,
                  acceleration: ArraySlice<Double>, policy: JointEvaluationPolicy) throws -> JointKinematics
    func integrating(_ manifold: JointManifold, q: ArraySlice<Double>, v: ArraySlice<Double>,
                     timeStep: Double, policy: JointEvaluationPolicy) throws -> [Double]
}
