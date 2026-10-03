import MechanicsCore
import MechanicsModel

public struct TreeKinematicsEvaluator: TreeKinematicsComputing, Sendable {
    public init() {}

    public func evaluate(_ tree: KinematicTree, state: KinematicState, policy: JointEvaluationPolicy) throws -> KinematicSnapshot {
        guard state.revision == tree.revision else { throw JointError.stateRevisionMismatch }
        guard state.q.count == tree.layout.positionCount, state.v.count == tree.layout.velocityCount,
              state.acceleration.count == tree.layout.velocityCount else { throw JointError.invalidCoordinateCount }
        var samples: [EntityID: FrameMotion] = [:]
        for sample in state.prescribedAnchors {
            guard tree.prescribedFrames.contains(sample.frame) else { throw JointError.unknownDerivativeData(sample.frame) }
            guard sample.time == state.time else { throw JointError.staleDerivativeData(sample.frame) }
            guard samples.updateValue(sample.motion, forKey: sample.frame) == nil else { throw JointError.duplicateIdentity(sample.frame) }
            if tree.bodies[0].dimension == .planar {
                try KinematicTree.validatingPlanar(sample.motion.pose)
                let velocity = sample.motion.velocity, acceleration = sample.motion.acceleration
                guard velocity.angular.x == 0, velocity.angular.y == 0, velocity.linear.z == 0,
                      acceleration.angular.x == 0, acceleration.angular.y == 0, acceleration.linear.z == 0 else {
                    throw JointError.nonplanarGeometry
                }
            }
        }
        for frame in tree.prescribedFrames {
            guard samples[frame] != nil else { throw JointError.missingDerivativeData(frame) }
        }
        let evaluator = JointMotionEvaluator(), composer = FrameMotionComposer()
        let count = tree.layout.velocityCount
        var motions: [FrameMotion] = []
        motions.reserveCapacity(tree.bodies.count)
        var columns: [SpatialMotion] = []
        columns.reserveCapacity(tree.bodies.count * count)
        var coordinateRate: [Double] = []
        coordinateRate.reserveCapacity(tree.layout.positionCount)
        var frames: [FrameKinematics] = []
        frames.reserveCapacity(tree.frameCount)
        frames.append(FrameKinematics(frame: tree.worldFrame, referenceFrame: tree.worldFrame, motion: .stationary(pose: .identity)))
        var jointFrames: [JointFrameKinematics] = []
        jointFrames.reserveCapacity(tree.joints.count)
        let rootMotion: FrameMotion
        let rootColumns: [SpatialMotion]
        switch tree.rootBase {
        case .fixed:
            rootMotion = .stationary(pose: tree.bodies[0].referencePose)
            rootColumns = []
        case .spatialFloating:
            let manifold = try JointManifold(.sixDOF)
            let evaluation = try evaluator.evaluate(manifold, q: state.q[0..<7], v: state.v[0..<6],
                                                     acceleration: state.acceleration[0..<6], policy: policy)
            rootMotion = evaluation.frameMotion; rootColumns = evaluation.subspace.columns
            coordinateRate.append(contentsOf: evaluation.coordinateRate)
        case .planarFloating:
            let manifold = try JointManifold(.planar(firstTranslationAxis: .unitX, secondTranslationAxis: .unitY))
            let evaluation = try evaluator.evaluate(manifold, q: state.q[0..<3], v: state.v[0..<3],
                                                     acceleration: state.acceleration[0..<3], policy: policy)
            rootMotion = evaluation.frameMotion; rootColumns = evaluation.subspace.columns
            coordinateRate.append(contentsOf: evaluation.coordinateRate)
        }
        motions.append(rootMotion)
        frames.append(FrameKinematics(frame: tree.bodies[0].frame, referenceFrame: tree.worldFrame, motion: rootMotion))
        columns.append(contentsOf: rootColumns)
        if rootColumns.count < count { columns.append(contentsOf: repeatElement(FrameMotion.zeroMotion, count: count - rootColumns.count)) }
        for bodyIndex in 1..<tree.bodies.count {
            let jointIndex = bodyIndex - 1
            let joint = tree.joints[jointIndex], layout = tree.layout.joints[jointIndex]
            let parentIndex = tree.parentIndices[bodyIndex], parent = motions[parentIndex]
            let parentAnchor = try anchorMotion(joint.parentAnchor, samples: samples)
            let childAnchor = try anchorMotion(joint.childAnchor, samples: samples)
            let worldParentAnchor = try composer.composed(parent: parent, relative: parentAnchor)
            let evaluation = try evaluator.evaluate(joint.manifold, q: state.q[layout.positions.range],
                v: state.v[layout.velocities.range], acceleration: state.acceleration[layout.velocities.range], policy: policy)
            let worldChildAnchor = try composer.composed(parent: worldParentAnchor, relative: evaluation.frameMotion)
            let body = try composer.composed(parent: worldChildAnchor, relative: composer.inverted(childAnchor))
            motions.append(body)
            let parentFrame = FrameKinematics(frame: joint.parentAnchor.frame, referenceFrame: tree.worldFrame, motion: worldParentAnchor)
            let childFrame = FrameKinematics(frame: joint.childAnchor.frame, referenceFrame: tree.worldFrame, motion: worldChildAnchor)
            frames.append(parentFrame); frames.append(childFrame)
            frames.append(FrameKinematics(frame: tree.bodies[bodyIndex].frame, referenceFrame: tree.worldFrame, motion: body))
            jointFrames.append(JointFrameKinematics(joint: joint.id, parentAnchor: parentFrame, childAnchor: childFrame, relative: evaluation))
            coordinateRate.append(contentsOf: evaluation.coordinateRate)
            let parentOffset = try body.pose.translation.subtracting(parent.pose.translation)
            let childAnchorOffset = try body.pose.translation.subtracting(worldChildAnchor.pose.translation)
            for columnIndex in 0..<count {
                let parentColumn = columns[parentIndex * count + columnIndex]
                var angular = parentColumn.angular
                var linear = try parentColumn.linear.adding(parentColumn.angular.cross(parentOffset))
                if layout.velocities.range.contains(columnIndex) {
                    let local = evaluation.subspace.columns[columnIndex - layout.velocities.start]
                    let extraAngular = try worldParentAnchor.pose.rotation.rotating(local.angular)
                    let extraLinear = try worldParentAnchor.pose.rotation.rotating(local.linear).adding(extraAngular.cross(childAnchorOffset))
                    angular = try angular.adding(extraAngular); linear = try linear.adding(extraLinear)
                }
                columns.append(SpatialMotion(angular: angular, linear: linear))
            }
        }
        var output: [BodyKinematics] = []
        output.reserveCapacity(tree.bodies.count)
        for index in tree.bodies.indices {
            let bodyColumns = columns[(index * count)..<((index + 1) * count)]
            let generalizedVelocity = try applying(columns: bodyColumns, values: state.v)
            let generalizedAcceleration = try applying(columns: bodyColumns, values: state.acceleration)
            let motion = motions[index], descriptor = tree.bodies[index]
            output.append(BodyKinematics(body: descriptor.id, bodyFrame: descriptor.frame, worldFrame: tree.worldFrame, motion: motion,
                prescribedDriftVelocity: SpatialMotion(angular: try motion.velocity.angular.subtracting(generalizedVelocity.angular),
                                                       linear: try motion.velocity.linear.subtracting(generalizedVelocity.linear)),
                accelerationBias: SpatialMotion(angular: try motion.acceleration.angular.subtracting(generalizedAcceleration.angular),
                                                 linear: try motion.acceleration.linear.subtracting(generalizedAcceleration.linear))))
        }
        return KinematicSnapshot(tree: tree, time: state.time, bodies: output, coordinateRate: coordinateRate, columns: columns, joints: jointFrames, frames: frames)
    }

    private func anchorMotion(_ anchor: JointAnchor, samples: [EntityID: FrameMotion]) throws -> FrameMotion {
        switch anchor.placement {
        case .fixed(let pose): return .stationary(pose: pose)
        case .prescribed:
            guard let sample = samples[anchor.frame] else { throw JointError.missingDerivativeData(anchor.frame) }
            return sample
        }
    }

    private func applying(columns: ArraySlice<SpatialMotion>, values: [Double]) throws -> SpatialMotion {
        var angular = Vector3.zero, linear = Vector3.zero
        for (index, column) in columns.enumerated() {
            angular = try angular.adding(column.angular.scaled(by: values[index]))
            linear = try linear.adding(column.linear.scaled(by: values[index]))
        }
        return SpatialMotion(angular: angular, linear: linear)
    }
}
