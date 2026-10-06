public struct ExactGeometryParameterDifferentiator: GeometryParameterDifferentiating, Sendable {
    public init() {}
    public func direction(_ source: GeometryParameterSource, direction: [Double], policy: GeometryParameterPolicy,
                          supplierWork: inout DerivativeSupplierWork, work: inout NumericalWork) throws(GeometryParameterError) -> GeometryParameterProduct {
        try GeometryParameterAdmission.validate(source, direction: direction, policy: policy, work: &work)
        let tree = source.tree, state = source.state, n = tree.layout.velocityCount, b = tree.bodies.count
        let bn = try GeometryParameterArithmetic.product(b, n)
        let storage = try GeometryParameterArithmetic.sum(GeometryParameterArithmetic.product(2048, b),
            GeometryParameterArithmetic.sum(GeometryParameterArithmetic.product(128, bn),
                GeometryParameterArithmetic.sum(GeometryParameterArithmetic.product(128, source.bindings.count), 2048)))
        try GeometryParameterArithmetic.storage(storage, &work)
        let geometry = try GeometryParameterAdmission.resolve(source, direction: direction, policy: policy, work: &work)
        try GeometryParameterArithmetic.checkpoint(policy)
        do throws(DerivativeError) { try supplierWork.chargeCall() } catch { throw .scalar(error) }
        let snapshot: KinematicSnapshot
        do { snapshot = try TreeKinematicsEvaluator().evaluate(tree, state: state, policy: policy.jointPolicy) }
        catch let error as JointError { throw .joints(error, failedSupplierWorkUnavailable: true) }
        catch let error as CoreError { throw .core(error) }
        catch { throw .unexpectedSupplierFailure }
        try GeometryParameterArithmetic.checkpoint(policy)
        var frames: [GeometryFrameJet] = [], columns: [GeometryMotionJet] = []
        var allFrames: [GeometryFrameJet] = []
        allFrames.reserveCapacity(tree.frameCount)
        frames.reserveCapacity(b); columns.reserveCapacity(bn)
        frames.append(try GeometryFrameJet.fixed(tree.bodies[0].referencePose, translation: geometry.translations[0],
                                                bodyRotation: geometry.bodyRotations[0], work: &work))
        allFrames.append(.identity); allFrames.append(frames[0])
        columns.append(contentsOf: repeatElement(GeometryMotionJet.zero, count: n))
        for i in 1..<b {
            try GeometryParameterArithmetic.checkpoint(policy)
            let joint = tree.joints[i - 1], layout = tree.layout.joints[i - 1]
            var parent: Int? = nil
            for j in 0..<i {
                try GeometryParameterArithmetic.checkpoint(policy); try GeometryParameterArithmetic.charge(1, &work)
                try GeometryParameterArithmetic.bytes(joint.parentBody.key, policy: policy, work: &work)
                try GeometryParameterArithmetic.bytes(tree.bodies[j].id.key, policy: policy, work: &work)
                if joint.parentBody == tree.bodies[j].id { parent = j; break }
            }
            guard let parent else { throw .derivativeUnavailable(.sourceMapping) }
            guard case .fixed(let parentPose) = joint.parentAnchor.placement,
                  case .fixed(let childPose) = joint.childAnchor.placement else { throw .derivativeUnavailable(.movingAnchor) }
            let parentSlot = 1 + 2*(i - 1), childSlot = parentSlot + 1
            let parentAnchor = try GeometryFrameJet.fixed(parentPose, translation: geometry.translations[parentSlot],
                                                         bodyRotation: geometry.bodyRotations[parentSlot], work: &work)
            let childAnchor = try GeometryFrameJet.fixed(childPose, translation: geometry.translations[childSlot],
                                                        bodyRotation: geometry.bodyRotations[childSlot], work: &work)
            let worldParent = try GeometryFrameJet.compose(frames[parent], parentAnchor, work: &work)
            let relative: GeometryFrameJet, local: GeometryMotionJet
            if joint.manifold.kind == .fixed { relative = .identity; local = .zero }
            else {
                let k = layout.velocities.start, axis = joint.manifold.orderedAxes[0]
                let axisJet = GeometryVectorJet(axis.direction, geometry.axes[k])
                let angular: GeometryVectorJet, linear: GeometryVectorJet, rotation: GeometryMatrixJet
                switch axis.kind {
                case .prismatic: angular = .zero; linear = axisJet; rotation = .identity
                case .revolute:
                    angular = axisJet; linear = .zero
                    rotation = try GeometryAxisRotation.evaluate(axisJet, coordinate: state.q[layout.positions.start], work: &work)
                case .screw:
                    angular = axisJet
                    linear = try GeometryParameterArithmetic.scale(axisJet, axis.pitchMetersPerRadian, &work)
                    rotation = try GeometryAxisRotation.evaluate(axisJet, coordinate: state.q[layout.positions.start], work: &work)
                }
                let coordinate = state.q[layout.positions.start]
                let translation: GeometryVectorJet
                if axis.kind == .screw {
                    translation = try GeometryParameterArithmetic.scale(axisJet, GeometryParameterArithmetic.finite(axis.pitchMetersPerRadian * coordinate), &work)
                } else { translation = try GeometryParameterArithmetic.scale(linear, coordinate, &work) }
                // The public joint evaluator converts the origin spatial generator to the moving endpoint.
                local = try GeometryMotionJet(angular, GeometryParameterArithmetic.add(linear, GeometryParameterArithmetic.cross(angular, translation, &work), &work))
                relative = try GeometryFrameJet(rotation: rotation,
                    translation: translation,
                    velocity: GeometryMotionJet(try GeometryParameterArithmetic.scale(angular, state.v[k], &work), GeometryParameterArithmetic.scale(linear, state.v[k], &work)),
                    acceleration: GeometryMotionJet(try GeometryParameterArithmetic.scale(angular, state.acceleration[k], &work), GeometryParameterArithmetic.scale(linear, state.acceleration[k], &work)))
            }
            let worldChild = try GeometryFrameJet.compose(worldParent, relative, work: &work)
            let body = try GeometryFrameJet.compose(worldChild, GeometryFrameJet.inverseFixed(childAnchor, work: &work), work: &work)
            let parentOffset = try GeometryParameterArithmetic.subtract(body.translation, frames[parent].translation, &work)
            let childOffset = try GeometryParameterArithmetic.subtract(body.translation, worldChild.translation, &work)
            for k in 0..<n {
                try GeometryParameterArithmetic.checkpoint(policy)
                let inherited = columns[parent*n + k]
                var angular = inherited.angular
                var linear = try GeometryParameterArithmetic.add(inherited.linear, GeometryParameterArithmetic.cross(inherited.angular, parentOffset, &work), &work)
                if layout.velocities.range.contains(k) {
                    let extraAngular = try GeometryParameterArithmetic.apply(worldParent.rotation, local.angular, &work)
                    let extraLinear = try GeometryParameterArithmetic.add(GeometryParameterArithmetic.apply(worldParent.rotation, local.linear, &work),
                        GeometryParameterArithmetic.cross(extraAngular, childOffset, &work), &work)
                    angular = try GeometryParameterArithmetic.add(angular, extraAngular, &work)
                    linear = try GeometryParameterArithmetic.add(linear, extraLinear, &work)
                }
                columns.append(GeometryMotionJet(angular, linear))
            }
            frames.append(body)
            allFrames.append(worldParent); allFrames.append(worldChild); allFrames.append(body)
        }
        return try publish(source: source, direction: direction, snapshot: snapshot, frames: frames, allFrames: allFrames, columns: columns,
                           geometry: geometry, policy: policy, supplierWork: &supplierWork, work: &work)
    }

    private func publish(source: GeometryParameterSource, direction: [Double], snapshot: KinematicSnapshot,
                         frames: [GeometryFrameJet], allFrames: [GeometryFrameJet], columns: [GeometryMotionJet], geometry: GeometryResolvedDirections,
                         policy: GeometryParameterPolicy, supplierWork: inout DerivativeSupplierWork,
                         work: inout NumericalWork) throws(GeometryParameterError) -> GeometryParameterProduct {
        let n = source.tree.layout.velocityCount, state = source.state
        var bodies: [GeometryBodyProduct] = [], directions: [SpatialMotion] = []
        var frameProducts: [GeometryFrameProduct] = []; frameProducts.reserveCapacity(allFrames.count)
        bodies.reserveCapacity(frames.count); directions.reserveCapacity(columns.count)
        var primal = GeometryOriginalAcceptance(), residual = GeometryOriginalAcceptance()
        guard allFrames.count == snapshot.frames.count else { throw .originalPrimalMismatch }
        for i in allFrames.indices {
            try GeometryParameterArithmetic.checkpoint(policy)
            let actual = snapshot.frames[i], jet = allFrames[i]
            try primal.vector(jet.translation.value, actual.motion.pose.translation, tolerance: policy.primalTolerance, primal: true, work: &work)
            let rotation = try GeometryParameterArithmetic.core { () throws(CoreError) in try actual.motion.pose.rotation.matrix() }
            try primal.matrix(jet.rotation.value, rotation, tolerance: policy.primalTolerance, work: &work)
            try primal.motion(jet.velocity.value, actual.motion.velocity, tolerance: policy.primalTolerance, primal: true, work: &work)
            try primal.motion(jet.acceleration.value, actual.motion.acceleration, tolerance: policy.primalTolerance, primal: true, work: &work)
            frameProducts.append(GeometryFrameProduct(frame: actual.frame, referenceFrame: actual.referenceFrame, jet: jet))
        }
        for i in frames.indices {
            try GeometryParameterArithmetic.checkpoint(policy)
            let actual = snapshot.bodies[i], frame = frames[i]
            try primal.vector(frame.translation.value, actual.motion.pose.translation, tolerance: policy.primalTolerance, primal: true, work: &work)
            let actualRotation = try GeometryParameterArithmetic.core { () throws(CoreError) in try actual.motion.pose.rotation.matrix() }
            try primal.matrix(frame.rotation.value, actualRotation, tolerance: policy.primalTolerance, work: &work)
            try primal.motion(frame.velocity.value, actual.motion.velocity, tolerance: policy.primalTolerance, primal: true, work: &work)
            try primal.motion(frame.acceleration.value, actual.motion.acceleration, tolerance: policy.primalTolerance, primal: true, work: &work)
            do throws(DerivativeError) { try supplierWork.chargeCall() } catch { throw .scalar(error) }
            let original: ArraySlice<SpatialMotion>
            do throws(JointError) { original = try snapshot.geometricColumns(body: actual.body) }
            catch { throw .joints(error, failedSupplierWorkUnavailable: true) }
            var jv = GeometryMotionJet.zero, ja = GeometryMotionJet.zero
            for (k, originalColumn) in original.enumerated() {
                try GeometryParameterArithmetic.checkpoint(policy)
                let column = columns[i*n + k]
                try primal.motion(column.value, originalColumn, tolerance: policy.primalTolerance, primal: true, work: &work)
                directions.append(column.direction)
                jv = try GeometryMotionJet(GeometryParameterArithmetic.add(jv.angular, GeometryParameterArithmetic.scale(column.angular, state.v[k], &work), &work),
                                       GeometryParameterArithmetic.add(jv.linear, GeometryParameterArithmetic.scale(column.linear, state.v[k], &work), &work))
                ja = try GeometryMotionJet(GeometryParameterArithmetic.add(ja.angular, GeometryParameterArithmetic.scale(column.angular, state.acceleration[k], &work), &work),
                                       GeometryParameterArithmetic.add(ja.linear, GeometryParameterArithmetic.scale(column.linear, state.acceleration[k], &work), &work))
            }
            let drift = try GeometryMotionJet(GeometryParameterArithmetic.subtract(frame.velocity.angular, jv.angular, &work), GeometryParameterArithmetic.subtract(frame.velocity.linear, jv.linear, &work))
            let bias = try GeometryMotionJet(GeometryParameterArithmetic.subtract(frame.acceleration.angular, ja.angular, &work), GeometryParameterArithmetic.subtract(frame.acceleration.linear, ja.linear, &work))
            try primal.motion(drift.value, actual.prescribedDriftVelocity, tolerance: policy.primalTolerance, primal: true, work: &work)
            try primal.motion(bias.value, actual.accelerationBias, tolerance: policy.primalTolerance, primal: true, work: &work)
            let reconstructedV = try GeometryMotionJet(GeometryParameterArithmetic.add(jv.angular, drift.angular, &work), GeometryParameterArithmetic.add(jv.linear, drift.linear, &work))
            let reconstructedA = try GeometryMotionJet(GeometryParameterArithmetic.add(ja.angular, bias.angular, &work), GeometryParameterArithmetic.add(ja.linear, bias.linear, &work))
            try residual.motion(reconstructedV.value, actual.motion.velocity, tolerance: policy.residualTolerance, primal: false, work: &work)
            try residual.motion(reconstructedA.value, actual.motion.acceleration, tolerance: policy.residualTolerance, primal: false, work: &work)
            try residual.motion(reconstructedV.direction, frame.velocity.direction, tolerance: policy.residualTolerance, primal: false, work: &work)
            try residual.motion(reconstructedA.direction, frame.acceleration.direction, tolerance: policy.residualTolerance, primal: false, work: &work)
            bodies.append(GeometryBodyProduct(body: actual.body, frame: actual.bodyFrame, translation: frame.translation.direction,
                rotationMatrix: frame.rotation.direction, velocity: frame.velocity.direction, acceleration: frame.acceleration.direction,
                prescribedDrift: drift.direction, accelerationBias: bias.direction))
        }
        try GeometryParameterArithmetic.checkpoint(policy)
        return GeometryParameterProduct(source: source, parameterDirection: direction, snapshot: snapshot, bodies: bodies,
            frames: frameProducts, geometricColumns: directions, coordinateRate: [Double](repeating: 0, count: state.q.count), normalizedAxes: geometry.witnesses,
            originalPrimal: primal.witness, originalMotionResidual: residual.witness, supplierWork: supplierWork, numericalWork: work)
    }
}
