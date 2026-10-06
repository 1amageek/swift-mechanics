public struct ReferenceAffineRigidGravityEvaluator: AffineRigidGravityEvaluating {
    public init() {}

    public func evaluate(_ input: AffineRigidGravityInput, policy: AffineRigidGravityPolicy,
                         work: inout LoadWork) throws(AffineRigidGravityFailure) -> AffineRigidGravityResponse {
        let a = AffineRigidGravityArithmetic.self
        try a.loads { () throws(LoadError) in try work.charge(0) }
        guard input.snapshot.tree.bodies.count <= policy.maximumBodies,
              input.snapshot.bodies.count == input.snapshot.tree.bodies.count else {
            throw .loads(.capacityExceeded)
        }
        try a.metadata(input.inertia.body.key, policy: policy, work: &work)
        try a.metadata(input.inertia.frame.key, policy: policy, work: &work)
        try a.metadata(input.field.frame.key, policy: policy, work: &work)
        try a.metadata(input.snapshot.tree.worldFrame.key, policy: policy, work: &work)
        guard input.expectedTimeSeconds.isFinite,
              input.snapshot.time == input.expectedTimeSeconds,
              input.snapshot.tree.revision == input.expectedRevision else { throw .staleSource }
        guard input.field.frame == input.snapshot.tree.worldFrame else { throw .frameMismatch }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Temporal gradients reach this instantaneous rigid-gravity port.
        // The original Gdot moment-energy/power contract must be implemented and qualified before success.
        guard input.gradientTimeDerivative == .zero else { throw .unsupportedGradientTimeDerivative }
        let index: Int
        do throws(JointError) { index = try input.snapshot.tree.bodyIndex(input.inertia.body) }
        catch { throw .joints(error) }
        let treeBody = input.snapshot.tree.bodies[index], body = input.snapshot.bodies[index]
        // FIXME(INCOMPLETE_IMPLEMENTATION): Planar sources reach this complete spatial tensor operation.
        // Original planar mass moments require a separate physical law without invented transverse inertia.
        guard treeBody.dimension == .spatial else { throw .unsupportedSpatialDomain }
        try a.metadata(treeBody.frame.key, policy: policy, work: &work)
        try a.metadata(body.body.key, policy: policy, work: &work)
        try a.metadata(body.bodyFrame.key, policy: policy, work: &work)
        try a.metadata(body.worldFrame.key, policy: policy, work: &work)
        guard body.body == input.inertia.body, body.bodyFrame == input.inertia.frame,
              treeBody.frame == input.inertia.frame, body.worldFrame == input.field.frame else { throw .frameMismatch }
        try a.loads { () throws(LoadError) in try work.reserve(scalars: 256); try work.charge(1024) }
        let properties = input.inertia.properties, field = input.field
        let q = try a.secondMoment(properties.inertiaAtCenter)
        let rotation = try a.core { () throws(CoreError) in try body.motion.pose.rotation.matrix() }
        let qw = try a.core { () throws(CoreError) in try rotation.multiplied(by: q).multiplied(by: rotation.transposed()) }
        let offset = try a.core { () throws(CoreError) in try rotation.applying(to: properties.centerOfMass) }
        let center = try a.core { () throws(CoreError) in try body.motion.pose.translation.adding(offset) }
        let velocity = try a.core { () throws(CoreError) in try body.motion.velocity.velocity(at: offset) }

        // The qualified original supplier is fixed; no external provider may replace its accounting.
        let gravity: any GravityEvaluating = GravityEvaluator()
        try a.loads { () throws(LoadError) in try work.charge(1) }
        let sample = try a.loads { () throws(LoadError) in try GravitySample(point: center, mass: properties.mass) }
        let point = try a.loads { () throws(LoadError) in try gravity.point(field, body: input.inertia.body, sample: sample, work: &work) }
        let image = try a.core { () throws(CoreError) in try field.gradient.applying(to: center) }
        let force = try a.core { () throws(CoreError) in try field.accelerationAtOrigin.adding(image).scaled(by: properties.mass) }
        let uniformPotential = try a.finite(-properties.mass * a.core { () throws(CoreError) in
            try field.accelerationAtOrigin.dot(center) + center.dot(image)/2
        })
        let explicitRate = try a.finite(-properties.mass * a.core { () throws(CoreError) in try field.uniformTimeDerivative.dot(center) })
        let forceDerivative = try a.core { () throws(CoreError) in try field.gradient.scaled(by: properties.mass) }
        guard point.load.body == input.inertia.body, point.load.frame == field.frame, point.load.point == center,
              point.load.forces.conservative == force, point.load.forces.dissipative == .zero,
              point.load.forces.active == .zero, point.load.potentialEnergy == uniformPotential,
              point.explicitPotentialTimeDerivative == explicitRate, point.forcePositionDerivative == forceDerivative else {
            throw .invalidSupplierOutput
        }
        let commutator = try a.core { () throws(CoreError) in
            try field.gradient.multiplied(by: qw).subtracting(qw.multiplied(by: field.gradient.transposed()))
        }
        let torque = try a.core { () throws(CoreError) in try Vector3(commutator.m21, commutator.m02, commutator.m10) }
        let originTorque = try a.core { () throws(CoreError) in try torque.adding(offset.cross(force)) }
        let wrench = SpatialWrench(torque: originTorque, force: force)
        let omega = body.motion.velocity.angular
        let skew = try a.core { () throws(CoreError) in
            try Matrix3(0,-omega.z,omega.y,omega.z,0,-omega.x,-omega.y,omega.x,0)
        }
        let qRate = try a.core { () throws(CoreError) in try skew.multiplied(by: qw).subtracting(qw.multiplied(by: skew)) }
        let momentPotential = try a.finite(-a.traceProduct(field.gradient, qw)/2)
        let potential = try a.finite(uniformPotential + momentPotential)
        let power = try a.finite(a.core { () throws(CoreError) in try force.dot(velocity) + torque.dot(omega) })
        let originPower = try a.core { () throws(CoreError) in try wrench.power(against: body.motion.velocity) }
        let driftPower = try a.core { () throws(CoreError) in try wrench.power(against: body.prescribedDriftVelocity) }
        let virtualPower = try a.finite(originPower-driftPower)
        // Differentiate the original integrals, independently of the returned wrench power.
        let translationRate = try a.finite(-properties.mass * a.core { () throws(CoreError) in
            try field.accelerationAtOrigin.dot(velocity) + velocity.dot(image)
        })
        let momentRate = try a.finite(-a.traceProduct(field.gradient, qRate)/2)
        let potentialRate = try a.finite(explicitRate+translationRate+momentRate)
        let originResidual = try a.finite(originPower-power)
        let conservativeResidual = try a.finite(potentialRate+power-explicitRate)
        guard try a.core({ () throws(CoreError) in
            try policy.powerAgreement.contains(error: originResidual, scale: max(abs(originPower),abs(power)))
        }), try a.core({ () throws(CoreError) in
            try policy.powerAgreement.contains(error: conservativeResidual,
                scale: max(abs(potentialRate),max(abs(power),abs(explicitRate))))
        }) else { throw .powerResidual }
        try a.loads { () throws(LoadError) in try work.charge(0) }
        let diagnostics = AffineRigidGravityDiagnostics(secondMomentBody: q, secondMomentWorld: qw,
            secondMomentWorldRate: qRate, secondMomentPotential: momentPotential, forcePositionDerivative: forceDerivative,
            mechanicalPower: power, bodyOriginPower: originPower, prescribedPower: driftPower, virtualPower: virtualPower,
            explicitPotentialTimeDerivative: explicitRate, potentialTimeDerivative: potentialRate,
            originTransportResidual: originResidual, conservativePowerResidual: conservativeResidual)
        return AffineRigidGravityResponse(input: input, centerOfMassWorld: center, centerOfMassVelocityWorld: velocity,
            force: force, torqueAtCenterOfMass: torque, wrenchAtBodyOrigin: wrench, potentialEnergy: potential, diagnostics: diagnostics)
    }

    public func staticBodyWrench(_ response: AffineRigidGravityResponse, otherGravityAppliedToBody: Bool,
                                work: inout LoadWork) throws(AffineRigidGravityFailure) -> BodyWrenchContribution {
        let a = AffineRigidGravityArithmetic.self
        try a.loads { () throws(LoadError) in try work.reserve(scalars: 64); try work.charge(16) }
        guard !otherGravityAppliedToBody else { throw .duplicateGravityOwnership }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Time-varying fields reach this existing BodyWrench bridge.
        // BodyWrenchContribution must carry explicit potential time power before complete temporal energy integration.
        guard response.input.field.uniformTimeDerivative == .zero,
              response.input.gradientTimeDerivative == .zero else { throw .unsupportedTemporalWrenchBridge }
        let body: BodyKinematics
        do throws(JointError) { body = try response.input.snapshot.body(response.input.inertia.body) }
        catch { throw .joints(error) }
        let result: BodyWrenchContribution
        do throws(DynamicsError) {
            result = try BodyWrenchContribution(body: response.input.inertia.body, frame: response.input.field.frame,
                referencePoint: body.motion.pose.translation, wrench: response.wrenchAtBodyOrigin,
                channel: .applied, potentialEnergy: response.potentialEnergy, dissipatedPower: 0)
        } catch { throw .dynamics(error) }
        try a.loads { () throws(LoadError) in try work.charge(0) }
        return result
    }
}
