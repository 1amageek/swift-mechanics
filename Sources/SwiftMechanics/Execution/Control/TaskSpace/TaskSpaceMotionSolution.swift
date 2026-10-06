internal struct TaskSpaceMotionSolution: Sendable {
    let jacobian: PointJacobian
    let pointMotion: PointKinematics
    let primary: [Double]
    let secondary: [Double]
    let total: [Double]
    let rank: Int
    let damping: Double
    let pointForce: Vector3
    let regularizationDefect: [Double]
    let secondaryRegularizationDefect: [Double]
}
