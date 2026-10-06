internal enum MJCFModelSampler {
    static func evaluate(_ model: MJCFImportedModel, state: CompiledKinematicState, controls: [Double], tolerance: NumericalTolerance,
                         transmitter: any ActuationTransmitting, constraints: any ConstraintEvaluating,
                         work: inout MJCFWork, actuationWork: inout ActuationWork, numericalWork: inout NumericalWork) throws(MJCFError) -> MJCFModelSample {
        guard controls.count == model.motors.count else { throw .invalidInput(node: -1, field: "controls") }
        try work.charge(0)
        let kinematics: KinematicSnapshot
        do { kinematics = try model.compiled.evaluate(state) } catch { throw .compilation(error) }
        var responses: [TransmissionResponse] = []
        try work.allocate(try MJCFArithmetic.product(model.motors.count, MemoryLayout<TransmissionResponse>.stride))
        try work.allocate(try MJCFArithmetic.product(try MJCFArithmetic.product(model.motors.count, model.joints.count), MemoryLayout<Double>.stride))
        for i in model.motors.indices {
            try work.charge(1)
            let port = model.motors[i]
            do { responses.append(try transmitter.affine(port.transmission, model: state.stamp, frame: model.compiled.descriptor.worldFrame,
                                                       effort: controls[i], rate: state.state.v, tolerance: tolerance, work: &actuationWork, numerical: &numericalWork)) }
            catch { throw .actuation(error) }
        }
        try work.allocate(try MJCFArithmetic.product(model.sensors.count, MemoryLayout<Double>.stride + MemoryLayout<PhysicalDimension>.stride))
        var values: [Double] = [], dimensions: [PhysicalDimension] = []
        for sensor in model.sensors {
            try work.charge(1)
            let value: Double, coordinate: ScalarCoordinateKind, velocity: Bool
            switch sensor.kind {
            case .jointPosition, .jointVelocity:
                let joint = model.joints[sensor.targetIndex]; coordinate = joint.coordinate
                velocity = sensor.kind == .jointVelocity
                value = try MJCFArithmetic.finite(velocity ? state.state.v[joint.velocityIndex] : state.state.q[joint.positionIndex] + joint.reference)
            case .tendonPosition, .tendonVelocity, .actuatorPosition, .actuatorVelocity:
                let tendon = sensor.kind == .tendonPosition || sensor.kind == .tendonVelocity
                let port = tendon ? model.tendons[sensor.targetIndex] : model.motors[sensor.targetIndex]
                coordinate = port.transmission.outputCoordinate
                velocity = sensor.kind == .tendonVelocity || sensor.kind == .actuatorVelocity
                var result = velocity ? 0 : port.referenceOffset
                // Fixed-root scalar charts have the same q/v ordering, established against the compiled layout at import.
                for i in port.transmission.gradient.indices {
                    try work.charge(2)
                    result = try MJCFArithmetic.finite(result + port.transmission.gradient[i] * (velocity ? state.state.v[i] : state.state.q[i]))
                }
                value = result
            }
            values.append(value)
            dimensions.append(PhysicalDimension(length: coordinate == .translation ? 1 : 0, time: velocity ? -1 : 0, angle: coordinate == .rotation ? 1 : 0))
        }
        var equality: ConstraintEvaluation?
        var physicalEqualities: [MJCFEqualitySample] = []
        if let system = model.equalitySystem {
            do {
                let policy = try ConstraintEvaluationPolicy(maximumCoordinates: model.joints.count, maximumRows: model.equalities.count,
                                                           expectedLayoutRevision: state.stamp.revision, isCancelled: work.policy.isCancelled)
                equality = try constraints.evaluate(system, position: state.state.q, velocity: state.state.v, time: state.state.time, policy: policy, work: &numericalWork)
            } catch { throw .constraints(error) }
            guard let equality else { throw .producerRejected(node: -1) }
            physicalEqualities = try MJCFOriginalEqualities.evaluate(bindings: model.equalities, system: system, evaluation: equality,
                                                                    position: state.state.q, context: model.context, work: &work)
        }
        try work.charge(0)
        return MJCFModelSample(stamp: state.stamp, state: state, source: model.context.source, kinematics: kinematics,
                               sensorValues: values, sensorDimensions: dimensions, motorResponses: responses, equalityEvaluation: equality, physicalEqualities: physicalEqualities)
    }
}
