import SwiftMechanics

enum ObservationProbeContext {
    struct UnrelatedMotionComposer: FrameMotionComposing {
        func composed(parent: FrameMotion, relative: FrameMotion) throws -> FrameMotion {
            .stationary(pose: .identity)
        }
        func inverted(_ frame: FrameMotion) throws -> FrameMotion {
            .stationary(pose: .identity)
        }
    }
    static func policy() throws -> ObservationPolicy {
        try ObservationPolicy(maximumBodies: 4, maximumCoordinates: 16,
            maximumReactionRows: 16, maximumMetadataBytes: 2048)
    }
    static func work() throws -> NumericalWork {
        NumericalWork(budget: try NumericalBudget(scalarStorage: 100000,
            arithmeticOperations: 1000000, iterations: 10000))
    }
    @inline(never)
    static func source() throws -> ObservationSource {
        let model = try MechanicalProbeModel().model
        let state = try model.makeState(KinematicState(revision: model.stamp.revision, time: 2,
            q: [0], v: [2], acceleration: [3]))
        var work = try work()
        let prepare: any ObservationSourcePreparing = ReferenceObservationSourcePreparer()
        return try prepare.prepare(model: model, state: state, solved: nil, policy: policy(), work: &work)
    }
    static func mount(offset: Double) throws -> ObservationMount {
        try ObservationMount(sensor: EntityID(kind: .sensor, key: "observation-probe-sensor"),
            body: EntityID(kind: .body, key: "compile-probe-child"),
            sensorFrame: EntityID(kind: .frame, key: "observation-probe-frame"),
            sensorToBody: RigidTransform(rotation: UnitQuaternion(axis: .unitZ, angle: .pi/2),
                translation: Vector3(offset, 0, 0)))
    }
    static func gravity(_ source: ObservationSource, time: Double = 2) throws -> ObservationGravity {
        try ObservationGravity(model: source.model.stamp, timeSeconds: time,
            field: AffineGravity(frame: source.snapshot.tree.worldFrame, accelerationAtOrigin: .zero))
    }
}
