public struct RollingConstraintEvaluator: RollingConstraintEvaluating, Sendable {
    public init() {}

    // FIXME(INCOMPLETE_IMPLEMENTATION): Only active thin rigid disk/smooth-plane queries are implemented.
    // The current production path is this source-bound evaluator; finite-width/deformable/multiple-contact
    // models, contact activation and accepted dynamics require their own physical implementation and
    // behavioral qualification before success may be claimed. Unsupported bindings fail explicitly below.
    public func evaluate(_ relation: RollingRelation, state: CompiledKinematicState,
                         prescribedPlane: RollingPrescribedPlaneSample?, policy: RollingEvaluationPolicy,
                         work: inout NumericalWork) throws(RollingError) -> RollingEvaluation {
        do {
            return try perform(relation, state: state, prescribedPlane: prescribedPlane, policy: policy, work: &work)
        } catch let error as RollingError { throw error }
        catch let error as NumericalError { throw .numerical(error) }
        catch let error as CompilationFailure { throw .compilation(error) }
        catch let error as JointError { throw .joints(error) }
        catch let error as CoreError { throw .geometry(error) }
        catch { throw .supplier(error) }
    }

    private func perform(_ relation: RollingRelation, state: CompiledKinematicState,
                         prescribedPlane: RollingPrescribedPlaneSample?, policy: RollingEvaluationPolicy,
                         work: inout NumericalWork) throws -> RollingEvaluation {
        try RollingArithmetic.check(policy)
        let model = relation.model, tree = model.tree, count = tree.layout.velocityCount
        guard state.stamp == model.stamp, state.state.revision == model.stamp.revision else { throw RollingError.staleSource }
        guard tree.bodies.count <= policy.maximumBodies, count <= policy.maximumCoordinates,
              state.state.q.count == tree.layout.positionCount, state.state.v.count == count,
              state.state.acceleration.count == count, policy.velocityScales.count == count else {
            throw RollingError.capacityExceeded
        }
        try RollingArithmetic.reserve(relation, sample: prescribedPlane, policy: policy, work: &work)
        let snapshot = try model.evaluate(state)
        try RollingArithmetic.check(policy)
        let wheelBody = try snapshot.body(relation.wheel.body)
        guard wheelBody.bodyFrame == relation.wheel.frame else { throw RollingError.unsupportedDomain }
        let plane = try RollingPlaneMotion.make(relation, snapshot: snapshot, sample: prescribedPlane)
        let calculator = KinematicJacobianCalculator()
        let center = try calculator.pointMotion(body: relation.wheel.body, bodyLocalPoint: relation.wheel.center, snapshot: snapshot)
        let wheelMotion = wheelBody.motion
        let axis = try wheelMotion.pose.rotation.rotating(relation.wheel.axis)
        let axisRate = try wheelMotion.velocity.angular.cross(axis)
        let normal = try plane.motion.pose.rotation.rotating(plane.normalLocal)
        let normalRate = try plane.motion.velocity.angular.cross(normal)
        let projection = try axis.dot(normal)
        let projectionRate = try axisRate.dot(normal) + axis.dot(normalRate)
        let projectedNormal = try normal.subtracting(axis.scaled(by: projection))
        let projectedRate = try normalRate.subtracting(axisRate.scaled(by: projection)).subtracting(axis.scaled(by: projectionRate))
        let chart = try projectedNormal.magnitude()
        guard chart > policy.minimumContactChartSine else { throw RollingError.invalidChart }
        let support = try projectedNormal.scaled(by: 1 / chart)
        let supportRate = try projectedRate.subtracting(support.scaled(by: support.dot(projectedRate))).scaled(by: 1 / chart)
        let offset = try support.scaled(by: -relation.wheel.radius)
        let offsetRate = try supportRate.scaled(by: -relation.wheel.radius)
        let contact = try center.position.adding(offset)
        let traceVelocity = try center.velocity.adding(offsetRate)
        let planeOrigin = try plane.motion.pose.transforming(point: plane.pointLocal)
        let gap = try normal.dot(contact.subtracting(planeOrigin))
        guard abs(gap) <= policy.contactTolerance else { throw RollingError.undefinedContact(gap: gap) }

        // These local points are frozen for the supplier query only. The transport corrections below
        // restore derivatives along the continuously reselected physical contact, avoiding rim locking.
        let wheelLocal = try wheelMotion.pose.inverted().transforming(point: contact)
        let planeLocal = try plane.motion.pose.inverted().transforming(point: contact)
        let wheelPoint = try calculator.pointMotion(body: relation.wheel.body, bodyLocalPoint: wheelLocal, snapshot: snapshot)
        let wheelJacobian = try calculator.point(body: relation.wheel.body, bodyLocalPoint: wheelLocal, snapshot: snapshot)
        let planePoint = try plane.contact(local: planeLocal, snapshot: snapshot, calculator: calculator)
        let relativeVelocity = try wheelPoint.velocity.subtracting(planePoint.velocity)
        let wheelTransport = try wheelMotion.velocity.angular.cross(offsetRate.subtracting(wheelMotion.velocity.angular.cross(offset)))
        let planeTransport = try plane.motion.velocity.angular.cross(traceVelocity.subtracting(planePoint.velocity))
        let relativeRate = try wheelPoint.acceleration.adding(wheelTransport)
            .subtracting(planePoint.acceleration.adding(planeTransport))
        let relativeBias = try wheelPoint.accelerationBias.adding(wheelTransport)
            .subtracting(planePoint.accelerationBias.adding(planeTransport))
        let relativeDrift = try wheelPoint.prescribedDriftVelocity.subtracting(planePoint.drift)

        let forwardRaw = try axis.cross(normal)
        let forward = try forwardRaw.scaled(by: 1 / chart)
        let forwardRawRate = try axisRate.cross(normal).adding(axis.cross(normalRate))
        let forwardRate = try forwardRawRate.subtracting(forward.scaled(by: forward.dot(forwardRawRate))).scaled(by: 1 / chart)
        let lateral = try normal.cross(forward)
        let lateralRate = try normalRate.cross(forward).adding(normal.cross(forwardRate))
        let directions = [normal, forward, lateral], rates = [normalRate, forwardRate, lateralRate]
        let kinds: [RollingRowKind] = [.normalNoPenetration, .forwardNoSlip, .lateralNoSlip]
        var rows: [RollingConstraintRow] = []; rows.reserveCapacity(3)
        for index in 0..<3 {
            try RollingArithmetic.check(policy)
            let direction = directions[index], rate = rates[index]
            var coefficients: [Double] = []; coefficients.reserveCapacity(count)
            var coordinateVelocity = 0.0, coordinateAcceleration = 0.0
            var velocityScale = 0.0, accelerationScale = 0.0
            for column in 0..<count {
                try RollingArithmetic.check(policy)
                let coefficient = try direction.dot(wheelJacobian.columns[column].subtracting(planePoint.columns[column]))
                coefficients.append(coefficient)
                let velocityTerm = try RollingArithmetic.finite(coefficient * state.state.v[column])
                let accelerationTerm = try RollingArithmetic.finite(coefficient * state.state.acceleration[column])
                coordinateVelocity = try RollingArithmetic.finite(coordinateVelocity + velocityTerm)
                coordinateAcceleration = try RollingArithmetic.finite(coordinateAcceleration + accelerationTerm)
                velocityScale = try RollingArithmetic.finite(velocityScale + abs(velocityTerm))
                accelerationScale = try RollingArithmetic.finite(accelerationScale + abs(accelerationTerm))
            }
            let drift = try direction.dot(relativeDrift)
            let movingBasis = try rate.dot(relativeVelocity)
            let bias = try RollingArithmetic.finite(direction.dot(relativeBias) + movingBasis)
            let velocityResidual = try direction.dot(relativeVelocity)
            let accelerationResidual = try RollingArithmetic.finite(direction.dot(relativeRate) + movingBasis)
            let velocityDifference = try RollingArithmetic.finite(coordinateVelocity + drift - velocityResidual)
            let accelerationDifference = try RollingArithmetic.finite(coordinateAcceleration + bias - accelerationResidual)
            let velocityLimit = try RollingArithmetic.finite(policy.absoluteVelocityTolerance + policy.relativeTolerance *
                max(velocityScale + abs(drift), abs(velocityResidual)))
            let accelerationLimit = try RollingArithmetic.finite(policy.absoluteAccelerationTolerance + policy.relativeTolerance *
                max(accelerationScale + abs(bias), abs(accelerationResidual)))
            guard abs(velocityDifference) <= velocityLimit, abs(accelerationDifference) <= accelerationLimit else {
                throw RollingError.inconsistentKinematics(rowID: relation.rowIDs[index])
            }
            let wheelPower = RollingPowerCovector(body: relation.wheel.body, frame: relation.wheel.frame,
                worldFrame: tree.worldFrame, pointWorld: contact, direction: direction)
            let planePower = RollingPowerCovector(body: plane.body, frame: plane.frame, worldFrame: tree.worldFrame,
                pointWorld: contact, direction: try direction.scaled(by: -1))
            rows.append(RollingConstraintRow(rowID: relation.rowIDs[index], kind: kinds[index], coefficients: coefficients,
                drift: drift, accelerationBias: bias, velocityResidual: velocityResidual, accelerationResidual: accelerationResidual,
                velocityDecompositionResidual: velocityDifference, accelerationDecompositionResidual: accelerationDifference,
                directionWorld: direction, directionRateWorld: rate, wheelPower: wheelPower, planePower: planePower))
        }
        let rank = try RollingRowRank.compute(rows, policy: policy)
        try RollingArithmetic.check(policy)
        return RollingEvaluation(modelStamp: model.stamp, sourceID: relation.sourceID, sourceRevision: relation.sourceRevision,
            referenceTime: relation.referenceTime, time: snapshot.time, worldFrame: tree.worldFrame,
            wheel: relation.wheel, plane: relation.plane, prescribedPlaneSourceID: plane.sourceID,
            prescribedPlaneSourceRevision: plane.sourceRevision,
            wheelFrameMotionWorld: wheelMotion, planeFrameMotionWorld: plane.motion,
            contactPointWorld: contact, contactTraceVelocityWorld: traceVelocity,
            wheelContactPointLocal: wheelLocal, planeContactPointLocal: planeLocal, axisWorld: axis,
            planeNormalWorld: normal, normalGap: gap, contactChartSine: chart,
            relativeMaterialVelocityWorld: relativeVelocity,
            wheelMaterialVelocityWorld: wheelPoint.velocity, planeMaterialVelocityWorld: planePoint.velocity,
            relativeMaterialVelocityRateWorld: relativeRate, rows: rows, rank: rank)
    }
}
