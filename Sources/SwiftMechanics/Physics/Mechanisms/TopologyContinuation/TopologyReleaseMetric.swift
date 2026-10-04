public enum TopologyReleaseMetric: UInt64, Equatable, Sendable {
    case explicitRelease = 0, torque = 1, force = 2, angularImpulse = 3, linearImpulse = 4
}
