internal struct PoseIKSample: Sendable {
    let state: KinematicState
    let snapshot: KinematicSnapshot
    let values: [Double]
    let jacobian: [Double]
    let physicalErrors: [Double]
    let physicalThresholds: [Double]
    let loopValues: [Double]
}
