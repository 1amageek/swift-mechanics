/// Original physical sensor values and actual qualified producer results at caller state/time.
public struct MJCFModelSample: Sendable {
    public let stamp: ModelStamp
    public let state: CompiledKinematicState
    public let source: SourceProvenance
    public let kinematics: KinematicSnapshot
    public let sensorValues: [Double]
    public let sensorDimensions: [PhysicalDimension]
    public let motorResponses: [TransmissionResponse]
    public let equalityEvaluation: ConstraintEvaluation?
    public let physicalEqualities: [MJCFEqualitySample]
    internal init(stamp: ModelStamp, state: CompiledKinematicState, source: SourceProvenance, kinematics: KinematicSnapshot,
                  sensorValues: [Double], sensorDimensions: [PhysicalDimension], motorResponses: [TransmissionResponse], equalityEvaluation: ConstraintEvaluation?, physicalEqualities: [MJCFEqualitySample]) {
        self.stamp = stamp; self.state = state; self.source = source; self.kinematics = kinematics
        self.sensorValues = sensorValues; self.sensorDimensions = sensorDimensions; self.motorResponses = motorResponses; self.equalityEvaluation = equalityEvaluation
        self.physicalEqualities = physicalEqualities
    }
}
