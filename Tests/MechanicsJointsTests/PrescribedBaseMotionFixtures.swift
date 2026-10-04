import SwiftMechanics

internal enum PrescribedBaseMotionFixtures {
    static func policy(cancelled: @escaping @Sendable () -> Bool = { false }) throws -> PrescribedMotionPolicy {
        try PrescribedMotionPolicy(maximumSamples: 1, maximumIdentifierBytes: 100, maximumMetadataBytes: 3000, isCancelled: cancelled)
    }
    static func work(storage: Int = 10000, operations: Int = 100000) throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: storage, arithmeticOperations: operations, iterations: 10))
    }
    static func law(planar: Bool = false, frame: String = "root", worldFrame: String = "world", rate: Double = 0.2,
                    maximumTime: Double = 8) throws -> AnalyticPrescribedMotion {
        let rotation = try UnitQuaternion(axis: planar ? .unitZ : .unitX, angle: 0.4)
        let translation = try Vector3(1, 2, planar ? 0 : 3)
        let velocity = try Vector3(0.4, -0.2, planar ? 0 : 0.1)
        let acceleration = try Vector3(0.3, 0.2, planar ? 0 : -0.1)
        return try AnalyticPrescribedMotion(frame: EntityID(kind: .frame, key: frame),
            parentFrame: EntityID(kind: .frame, key: worldFrame), referenceTime: 0,
            initialPose: RigidTransform(rotation: planar ? rotation : rotation.negated(), translation: translation),
            translationRate: velocity, translationAcceleration: acceleration, rotationAxis: .unitZ,
            angularRate: rate, angularAcceleration: 0.3, minimumTime: -1, maximumTime: maximumTime, maximumIdentifierBytes: 100)
    }
    static func program(planar: Bool = false, frame: String = "root", worldFrame: String = "world", rate: Double = 0.2,
                        maximumTime: Double = 8) throws -> PrescribedBaseMotionProgram {
        var ledger = try work()
        return try PrescribedBaseMotionProgram(law: law(planar: planar, frame: frame, worldFrame: worldFrame, rate: rate, maximumTime: maximumTime),
            layout: planar ? .planarFloating : .spatialFloating, policy: policy(), work: &ledger)
    }
}
