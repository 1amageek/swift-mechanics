/// Explicit radial combined-brush approximation with a calibrated passive rolling couple.
public struct RadialBrushTireLaw: TireRoadEvaluating {
    public init() {}

    public func evaluate(sample: TireRoadSample, frame: TireRoadFrame, calibration: TireBrushCalibration,
                         policy: TireAcceptancePolicy, work: inout LoadWork) throws(TireLawError) -> TireRoadResponse {
        try tireLoad { () throws(LoadError) in try work.reserve(scalars: 192) }
        try chargeMetadata(sample: sample, frame: frame, calibration: calibration, work: &work)
        guard sample.referenceFrame == frame.reference else { throw .frameMismatch }
        guard sample.tire == calibration.tire, sample.roadSurface == calibration.roadSurface,
              sample.calibrationRevision == calibration.revision else { throw .calibrationMismatch }
        try tireLoad { () throws(LoadError) in try work.charge(1) }

        let domain = calibration.domain
        guard sample.radius >= domain.minimumRadius, sample.radius <= domain.maximumRadius,
              sample.normalLoad >= domain.minimumNormalLoad, sample.normalLoad <= domain.maximumNormalLoad,
              abs(sample.spin) <= domain.maximumAbsoluteSpin else { throw .outsideCalibratedDomain }
        let relative = try tireCore { () throws(CoreError) in
            try frame.contactToReference.conjugated().rotating(
                sample.centerVelocity.subtracting(sample.roadContactVelocity))
        }
        let speed = abs(relative.x)
        // FIXME(INCOMPLETE_IMPLEMENTATION): Static/low-speed tire contact has no calibrated
        // constitutive implementation. The public evaluate path explicitly rejects it;
        // success needs an independently calibrated static/transition law and power proof.
        guard speed >= domain.minimumAbsoluteLongitudinalSpeed else { throw .lowSpeedDomain }
        guard speed <= domain.maximumAbsoluteLongitudinalSpeed,
              abs(relative.y) <= domain.maximumAbsoluteLateralSpeed else { throw .outsideCalibratedDomain }
        guard abs(relative.z) <= policy.normalSpeedTolerance else { throw .contactGeometryMismatch }
        let offset = try tireCore { () throws(CoreError) in
            try frame.contactToReference.rotating(Vector3(0, 0, -sample.radius))
        }
        let point = try tireCore { () throws(CoreError) in try sample.centerPosition.adding(offset) }
        let planeSeparation = try tireCore { () throws(CoreError) in
            try frame.contactToReference.conjugated().rotating(point.subtracting(frame.planePoint)).z
        }
        guard abs(planeSeparation) <= policy.contactDistanceTolerance else { throw .contactGeometryMismatch }

        let surfaceSpeed = try tireFinite(relative.x - tireFinite(sample.radius * sample.spin))
        let ratio = try tireFinite(-surfaceSpeed / speed)
        let tangent = try tireFinite(relative.y / speed)
        let angle = try tireFinite(ScalarMath.angle(y: relative.y, x: speed))
        guard surfaceSpeed == 0 || ratio != 0, relative.y == 0 || tangent != 0 else { throw .nonFiniteResult }
        guard abs(ratio) <= domain.maximumAbsoluteSlipRatio,
              abs(tangent) <= domain.maximumAbsoluteLateralSlipTangent else { throw .outsideCalibratedDomain }
        let slip = TireSlip(longitudinalRatio: ratio, lateralAngle: angle, lateralTangent: tangent,
                            longitudinalSurfaceSpeed: surfaceSpeed, lateralSurfaceSpeed: relative.y)

        let qx = try tireFinite(calibration.longitudinalStiffness * ratio)
        let qy = try tireFinite(-calibration.lateralStiffness * tangent)
        guard ratio == 0 || qx != 0, tangent == 0 || qy != 0 else { throw .nonFiniteResult }
        let demand = try tireFinite(ScalarMath.norm(qx, qy))
        let capacity = try tireFinite(calibration.frictionCoefficient * sample.normalLoad)
        guard capacity > 0 else { throw .nonFiniteResult }
        // Divide the demand before comparison to avoid overflowing 3*capacity.
        let saturated = demand >= capacity && demand / 3 >= capacity
        let fx: Double, fy: Double
        if demand == 0 {
            fx = 0; fy = 0
        } else {
            let forceMagnitude: Double
            if saturated { forceMagnitude = capacity }
            else {
                let a = try tireFinite(demand / capacity)
                forceMagnitude = try tireFinite(demand * (1 - a / 3 + a * a / 27))
            }
            guard forceMagnitude > 0 else { throw .nonFiniteResult }
            fx = try tireFinite((qx / demand) * forceMagnitude)
            fy = try tireFinite((qy / demand) * forceMagnitude)
            guard fx != 0 || fy != 0 else { throw .nonFiniteResult }
        }
        let rollingCapacity = try tireFinite(calibration.rollingResistanceLength * sample.normalLoad)
        guard calibration.rollingResistanceLength == 0 || rollingCapacity > 0 else { throw .nonFiniteResult }
        let rollingMoment = sample.spin == 0 ? 0 : (sample.spin > 0 ? -rollingCapacity : rollingCapacity)
        let force = try tireCore { () throws(CoreError) in
            try frame.contactToReference.rotating(Vector3(fx, fy, 0))
        }
        let rollingCouple = try tireCore { () throws(CoreError) in
            try frame.contactToReference.rotating(Vector3(0, rollingMoment, 0))
        }
        let centerTorque = try tireCore { () throws(CoreError) in try offset.cross(force).adding(rollingCouple) }
        let centerWrench = SpatialWrench(torque: centerTorque, force: force)
        let roadWrench = try tireCore { () throws(CoreError) in
            SpatialWrench(torque: try rollingCouple.scaled(by: -1), force: try force.scaled(by: -1))
        }
        let load = try tireLoad { () throws(LoadError) in
            try FramedPointLoad(body: sample.tire.id, frame: frame.reference.id, point: point,
                                forces: ForceParts(dissipative: force))
        }
        let power = try accept(sample: sample, frame: frame, slip: slip, centerWrench: centerWrench,
                               roadWrench: roadWrench, rollingCouple: rollingCouple,
                               capacity: capacity, policy: policy)
        try tireLoad { () throws(LoadError) in try work.charge(0) }
        return TireRoadResponse(sample: sample, frame: frame, calibration: calibration, slip: slip,
            tangentialPointLoad: load, wheelCenterWrench: centerWrench, roadContactWrench: roadWrench,
            longitudinalForce: fx, lateralForce: fy, rollingMoment: rollingMoment,
            isForceSaturated: saturated, power: power)
    }

    private func accept(sample: TireRoadSample, frame: TireRoadFrame, slip: TireSlip,
                        centerWrench: SpatialWrench, roadWrench: SpatialWrench, rollingCouple: Vector3,
                        capacity: Double, policy: TireAcceptancePolicy) throws(TireLawError) -> TirePowerDiagnostics {
        let angular = try tireCore { () throws(CoreError) in
            try frame.contactToReference.rotating(Vector3(0, sample.spin, 0))
        }
        let slipVelocity = try tireCore { () throws(CoreError) in
            try frame.contactToReference.rotating(Vector3(slip.longitudinalSurfaceSpeed, slip.lateralSurfaceSpeed, 0))
        }
        let wheelPower = try tireCore { () throws(CoreError) in
            try centerWrench.power(against: SpatialMotion(angular: angular, linear: sample.centerVelocity))
        }
        let roadPower = try tireCore { () throws(CoreError) in try roadWrench.force.dot(sample.roadContactVelocity) }
        let slipLoss = try tireCore { () throws(CoreError) in try -centerWrench.force.dot(slipVelocity) }
        let rollingLoss = try tireCore { () throws(CoreError) in try -rollingCouple.dot(angular) }
        let residual = try tireFinite(wheelPower + roadPower + slipLoss + rollingLoss)
        let pairPower = try tireFinite(wheelPower + roadPower)
        let forceExcess = try tireCore { () throws(CoreError) in try centerWrench.force.magnitude() - capacity }
        let powerScale = max(policy.referencePower, max(abs(wheelPower), max(abs(roadPower),
                             max(abs(slipLoss), abs(rollingLoss)))))
        let powerTolerance = try tireFinite(policy.absolutePowerTolerance + policy.relativeTolerance * powerScale)
        let passiveScale = max(policy.referencePower, max(abs(slipLoss), abs(rollingLoss)))
        let passiveTolerance = try tireFinite(policy.absolutePowerTolerance + policy.relativeTolerance * passiveScale)
        let forceTolerance = try tireFinite(policy.absoluteForceTolerance +
                                            policy.relativeTolerance * max(policy.referenceForce, capacity))
        guard slipLoss >= -passiveTolerance, rollingLoss >= -passiveTolerance,
              pairPower <= passiveTolerance, abs(residual) <= powerTolerance,
              forceExcess <= forceTolerance else { throw .physicalAcceptanceFailed }
        return TirePowerDiagnostics(wheelMechanicalPower: wheelPower, roadMechanicalPower: roadPower,
            slipDissipationPower: slipLoss, rollingDissipationPower: rollingLoss,
            originalPowerResidual: residual, originalForceConeExcess: forceExcess)
    }

    private func chargeMetadata(sample: TireRoadSample, frame: TireRoadFrame,
                                calibration: TireBrushCalibration, work: inout LoadWork) throws(TireLawError) {
        try charge(sample.tire.id.key, work: &work)
        try charge(sample.roadSurface.id.key, work: &work)
        try charge(sample.referenceFrame.id.key, work: &work)
        try charge(frame.reference.id.key, work: &work)
        try charge(calibration.tire.id.key, work: &work)
        try charge(calibration.roadSurface.id.key, work: &work)
        try charge(calibration.source, work: &work)
        try charge(TireBrushCalibration.formulation, work: &work)
    }

    private func charge(_ text: String, work: inout LoadWork) throws(TireLawError) {
        for _ in text.utf8 { try tireLoad { () throws(LoadError) in try work.charge(1) } }
    }
}
