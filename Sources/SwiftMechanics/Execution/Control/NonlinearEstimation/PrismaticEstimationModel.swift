public struct PrismaticEstimationModel: Sendable {
    public let model: CompiledMechanicalModel
    public let joint: EntityID
    public let parentAnchorFrame: EntityID
    public let passiveLaw: PolynomialSpringDamper
    public let positionScaleMeters: Double
    public let rateScaleMetersPerSecond: Double
    public let positionDimension = PhysicalDimension.length
    public let rateDimension = PhysicalDimension.velocity
    public let movingMassKilograms: Double
    internal let inertias: [RigidBodyInertia]

    public init(model: CompiledMechanicalModel, joint: EntityID, passiveLaw: PolynomialSpringDamper,
                positionScaleMeters: Double, rateScaleMetersPerSecond: Double,
                policy: NonlinearEstimatorPolicy, work: inout NumericalWork) throws(NonlinearEstimatorFailure) {
        do {
            try EstimatorArithmetic.charge(256, policy: policy, work: &work)
            try EstimatorArithmetic.reserve(512, policy: policy, work: &work)
            // FIXME(INCOMPLETE_IMPLEMENTATION): General mechanical topology and extension force/state semantics are not implemented by this selected EKF admission. Production callers enter here; those sources must remain typed failures until original dynamics, exact tangents, observation binding and bounded propagation are implemented and independently qualified.
            guard model.tree.bodies.count == 2, model.descriptor.bodies.count == 2, model.tree.joints.count == 1,
                  model.descriptor.joints.count == 1, model.tree.layout.positionCount == 1, model.tree.layout.velocityCount == 1,
                  model.tree.rootBase == .fixed, model.descriptor.rootAuthority == .fixed,
                  model.tree.bodies[0].referencePose == .identity, model.descriptor.initialState.prescribedAnchors.isEmpty,
                  model.descriptor.extensions.isEmpty,
                  passiveLaw.coordinateKind == .translation, passiveLaw.quarticStiffness > 0 || passiveLaw.cubicDamping > 0 else { throw NonlinearEstimatorCause.unsupportedModel }
            guard positionScaleMeters.isFinite, positionScaleMeters > 0, rateScaleMetersPerSecond.isFinite, rateScaleMetersPerSecond > 0,
                  (positionScaleMeters*positionScaleMeters).isFinite, positionScaleMeters*positionScaleMeters > 0,
                  (rateScaleMetersPerSecond/positionScaleMeters).isFinite, rateScaleMetersPerSecond/positionScaleMeters > 0,
                  (positionScaleMeters/rateScaleMetersPerSecond).isFinite, positionScaleMeters/rateScaleMetersPerSecond > 0 else { throw NonlinearEstimatorCause.invalidInput }
            let record = model.tree.joints[0]
            guard record.id == joint, record.manifold.kind == .prismatic, record.manifold.orderedAxes.count == 1,
                  record.manifold.orderedAxes[0].direction == .unitX, model.descriptor.joints[0].authority == .dynamicState,
                  record.parentAnchor.placement == .fixed(.identity), record.childAnchor.placement == .fixed(.identity) else { throw NonlinearEstimatorCause.unsupportedModel }
            for text in [model.stamp.identity, joint.key, model.tree.worldFrame.key, record.parentAnchor.frame.key,
                         record.childAnchor.frame.key, model.tree.bodies[0].id.key, model.tree.bodies[0].frame.key,
                         model.tree.bodies[1].id.key, model.tree.bodies[1].frame.key] {
                guard text.utf8.count <= policy.maximumMetadataBytes else { throw NonlinearEstimatorCause.capacityExceeded }
                try EstimatorArithmetic.charge(text.utf8.count, policy: policy, work: &work)
            }
            var inertias: [RigidBodyInertia] = [], movingMass: Double?
            for body in model.tree.bodies {
                guard body.dimension == .spatial, let source = model.descriptor.bodies.first(where: { $0.id == body.id }),
                      case .spatial(let spatial) = source, let representation = spatial.inertia,
                      representation.properties.centerOfMass == .zero else { throw NonlinearEstimatorCause.unsupportedModel }
                if body.id == record.childBody {
                    guard spatial.mode == .dynamic else { throw NonlinearEstimatorCause.unsupportedModel }
                    movingMass = representation.properties.mass
                } else { guard spatial.mode == .static else { throw NonlinearEstimatorCause.unsupportedModel } }
                do { inertias.append(try RigidBodyInertia(body: body.id, frame: body.frame, properties: representation.properties)) }
                catch { throw NonlinearEstimatorCause.dynamics(error) }
            }
            guard let mass = movingMass, mass > 0 else { throw NonlinearEstimatorCause.unsupportedModel }
            self.model = model; self.joint = joint; parentAnchorFrame = record.parentAnchor.frame; self.passiveLaw = passiveLaw
            self.positionScaleMeters = positionScaleMeters; self.rateScaleMetersPerSecond = rateScaleMetersPerSecond
            movingMassKilograms = mass; self.inertias = inertias
        } catch let error as NonlinearEstimatorCause {
            throw NonlinearEstimatorFailure(cause: error, phase: "model-admission", work: work, derivativeCalls: 0)
        } catch { throw NonlinearEstimatorFailure(cause: .invalidSupplierOutput, phase: "model-admission", work: work, derivativeCalls: 0) }
    }

    internal func validateMetadata(policy: NonlinearEstimatorPolicy, work: inout NumericalWork) throws(NonlinearEstimatorCause) {
        let record = model.tree.joints[0]
        for text in [model.stamp.identity, joint.key, model.tree.worldFrame.key, record.parentAnchor.frame.key,
                     record.childAnchor.frame.key, model.tree.bodies[0].id.key, model.tree.bodies[0].frame.key,
                     model.tree.bodies[1].id.key, model.tree.bodies[1].frame.key] {
            guard text.utf8.count <= policy.maximumMetadataBytes else { throw .capacityExceeded }
            try EstimatorArithmetic.charge(text.utf8.count, policy: policy, work: &work)
        }
    }

    internal func domain(position: Double, rate: Double, policy: NonlinearEstimatorPolicy) throws(NonlinearEstimatorCause) {
        guard position.isFinite, rate.isFinite, abs(position) <= policy.maximumCoordinateMagnitudeMeters,
              abs(rate) <= policy.maximumRateMagnitudeMetersPerSecond,
              abs(position-passiveLaw.restCoordinate) <= passiveLaw.maximumDisplacement, abs(rate) <= passiveLaw.maximumRate else { throw .outsidePhysicalDomain }
    }

    @inline(never)
    internal func sample(time: Double, position q: Double, rate v: Double, effort: Double, policy: NonlinearEstimatorPolicy,
                         calls: inout DerivativeSupplierWork, work: inout NumericalWork) throws(NonlinearEstimatorCause) -> EstimatorMechanicalSample {
        try domain(position: q, rate: v, policy: policy)
        guard time.isFinite, effort.isFinite, abs(effort) <= policy.maximumEffortNewtons else { throw .invalidInput }
        try EstimatorArithmetic.charge(16384, policy: policy, work: &work)
        var nested = try EstimatorArithmetic.nested(work, reserved: 2048, policy: policy)
        var result: EstimatorMechanicalSample?, failure: NonlinearEstimatorCause?
        do { result = try actualSample(time: time, position: q, rate: v, effort: effort, policy: policy, calls: &calls, work: &nested) }
        catch { failure = error }
        try EstimatorArithmetic.absorb(nested, into: &work, reserved: 2048)
        if let failure { throw failure }; guard let result else { throw .invalidSupplierOutput }; return result
    }

    @inline(never)
    private func actualSample(time: Double, position q: Double, rate v: Double, effort: Double, policy: NonlinearEstimatorPolicy,
                              calls: inout DerivativeSupplierWork, work: inout NumericalWork) throws(NonlinearEstimatorCause) -> EstimatorMechanicalSample {
        let state: KinematicState, snapshot: KinematicSnapshot
        do { state = try KinematicState(revision: model.stamp.revision, time: time, q: [q], v: [v], acceleration: [0]) }
        catch { throw .joints(error) }
        do { snapshot = try model.evaluate(model.makeState(state)) } catch { throw .compilation(error) }
        let law: ScalarLoadResponse
        var load: LoadWork
        do { load = LoadWork(budget: try LoadBudget(maximumWork: 1, maximumScalars: 0, isCancelled: policy.isCancelled))
             law = try ScalarLoadEvaluator().evaluate(passiveLaw, coordinate: q, rate: v, work: &load) }
        catch { throw .loads(error) }
        try EstimatorArithmetic.charge(1, policy: policy, work: &work)
        let force = try EstimatorArithmetic.finite(law.conservative+law.dissipative+law.active)
        let contribution: GeneralizedForceContribution, system: RigidDynamicsSystem, solved: DynamicsSolution
        let admission = try dynamicsAdmission(policy)
        do {
            contribution = try GeneralizedForceContribution(values: [force], channel: .applied, potentialEnergy: law.potentialEnergy, dissipatedPower: law.dissipatedPower)
            let input = try RigidDynamicsInput(snapshot: snapshot, velocity: [v], inertias: inertias, gravity: nil, generalizedForces: [contribution])
            system = try RigidEquationKernel().assemble(input, admission: admission, loadWork: &load, work: &work)
            solved = try DenseRigidDynamics().forward(system, driveForce: [effort], policy: policy.dynamics, work: &work)
        } catch { throw .dynamics(error) }
        guard system.velocityCount == 1, system.massMatrix.count == 1, system.inertialBias.count == 1,
              solved.acceleration.count == 1, solved.originalPhysicalResidual.isAccepted,
              try EstimatorArithmetic.agreement(system.massMatrix[0], movingMassKilograms, policy.physicalAgreement),
              try EstimatorArithmetic.agreement(system.inertialBias[0], 0, policy.physicalAgreement),
              try EstimatorArithmetic.agreement(solved.acceleration[0], (effort+force)/movingMassKilograms, policy.physicalAgreement) else { throw .physicalEvidenceRejected }
        let derivativeInput = MechanicalDerivativeInput(tree: model.tree, state: state, inertias: inertias, gravity: nil,
            generalizedForces: [contribution], drive: [effort])
        var workspace = MechanicalDerivativeWorkspace()
        let dq = try tangent(derivativeInput, configuration: 1, velocity: 0, forceDerivative: law.coordinateDerivative,
                             acceleration: solved.acceleration[0], admission: admission, policy: policy, workspace: &workspace, calls: &calls, work: &work)
        let dv = try tangent(derivativeInput, configuration: 0, velocity: 1, forceDerivative: law.rateDerivative,
                             acceleration: solved.acceleration[0], admission: admission, policy: policy, workspace: &workspace, calls: &calls, work: &work)
        guard try EstimatorArithmetic.agreement(dq, law.coordinateDerivative/movingMassKilograms, policy.physicalAgreement),
              try EstimatorArithmetic.agreement(dv, law.rateDerivative/movingMassKilograms, policy.physicalAgreement) else { throw .derivativeEvidenceRejected }
        return EstimatorMechanicalSample(acceleration: solved.acceleration[0], coordinateDerivative: dq, rateDerivative: dv)
    }

    @inline(never)
    private func tangent(_ input: MechanicalDerivativeInput, configuration: Double, velocity: Double, forceDerivative: Double,
                         acceleration: Double, admission: DynamicsAdmission, policy: NonlinearEstimatorPolicy,
                         workspace: inout MechanicalDerivativeWorkspace, calls: inout DerivativeSupplierWork,
                         work: inout NumericalWork) throws(NonlinearEstimatorCause) -> Double {
        let direction = MechanicalDirection(tree: TreeDirection(revision: model.stamp.revision, configuration: [configuration],
            velocity: [velocity], acceleration: [0], screwPitch: [0]),
            inertias: inertias.map { BodyInertiaDirection(body: $0.body, frame: $0.frame) }, generalizedForces: [[forceDerivative]], drive: [0])
        var load: LoadWork
        do { load = LoadWork(budget: try LoadBudget(maximumWork: 0, maximumScalars: 0, isCancelled: policy.isCancelled)) }
        catch { throw .loads(error) }
        let result: AccelerationTangent
        do { result = try ExactMechanicalDifferentiator().forwardDirection(input, direction: direction,
            jointPolicy: model.policy.jointPolicy, admission: admission, solvePolicy: policy.dynamics, policy: policy.derivatives,
            workspace: &workspace, loadWork: &load, supplierWork: &calls, work: &work) }
        catch { throw .derivatives(error) }
        guard result.acceleration.count == 1, result.acceleration[0].isFinite, result.originalResidual <= result.originalThreshold,
              result.primal.originalPhysicalResidual.isAccepted, result.primal.acceleration.count == 1,
              try EstimatorArithmetic.agreement(result.primal.acceleration[0], acceleration, policy.physicalAgreement) else { throw .derivativeEvidenceRejected }
        return result.acceleration[0]
    }

    internal func dynamicsAdmission(_ policy: NonlinearEstimatorPolicy) throws(NonlinearEstimatorCause) -> DynamicsAdmission {
        do { return DynamicsAdmission(capacity: try DynamicsCapacity(maximumBodies: 2, maximumVelocities: 1, maximumBodyWrenches: 0,
            maximumGeneralizedContributions: 1), angularVelocityTolerance: policy.physicalAgreement,
            linearVelocityTolerance: policy.physicalAgreement, isCancelled: policy.isCancelled) }
        catch { throw .dynamics(error) }
    }

    @inline(never)
    internal func encoder(time: Double, position: Double, rate: Double, acceleration: Double, policy: NonlinearEstimatorPolicy,
                          work: inout NumericalWork) throws(NonlinearEstimatorCause) -> JointEncoderObservation {
        try EstimatorArithmetic.charge(16384, policy: policy, work: &work)
        try domain(position: position, rate: rate, policy: policy)
        let state: CompiledKinematicState
        do {
            let physical = try KinematicState(revision: model.stamp.revision, time: time, q: [position], v: [rate], acceleration: [acceleration])
            do { state = try model.makeState(physical) } catch { throw NonlinearEstimatorCause.compilation(error) }
        } catch let error as NonlinearEstimatorCause { throw error }
        catch let error as JointError { throw .joints(error) }
        catch { throw .invalidInput }
        let result: JointEncoderObservation
        do {
            let source = try ReferenceObservationSourcePreparer().prepare(model: model, state: state, policy: policy.observations, work: &work)
            result = try ReferenceKinematicObserver().encoder(source: source, joint: joint, policy: policy.observations, work: &work)
        } catch { throw .observations(error) }
        guard result.model == model.stamp, result.timeSeconds == time, result.joint == joint, result.parentAnchorFrame == parentAnchorFrame,
              result.positions == [position], result.velocities == [rate], result.coordinateRates == [rate], result.accelerations == [acceleration],
              result.positionUnits == [.length], result.coordinateRateUnits == [.velocity], result.velocityUnits == [.velocity],
              result.accelerationUnits == [.acceleration], result.accelerationAuthority == .suppliedState,
              result.velocityConvention == .orderedAxisRates, result.temporalMeaning == .instantaneousContinuous else { throw .sourceMismatch }
        return result
    }
}
