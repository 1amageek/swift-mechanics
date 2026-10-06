/// Concrete composition of admitted mechanical, transmission, passive and actuation producers.
public struct ReferenceStructuralSystemCompiler: StructuralSystemCompiling {
    public let mechanical: any MechanicalModelCompiling
    public init(mechanical: any MechanicalModelCompiling = ReferenceMechanicalCompiler(extensions: NoMechanicalExtensions())) {
        self.mechanical = mechanical
    }

    // FIXME(INCOMPLETE_IMPLEMENTATION): This source-only composition admits fixed-root
    // dynamic scalar joints, fixed-support ideal gears, scalar passive laws and constant
    // torque sources. General charts/supports and original equation/runtime proof remain open.
    public func compile(_ draft: StructuralPhysicsDraft, compilationPolicy: CompilationPolicy,
        policy: StructuralSystemPolicy, work: inout NumericalWork, transmissionWork: inout NumericalWork,
        loadWork: inout LoadWork, actuationWork: inout ActuationWork
    ) throws(StructuralSystemFailure) -> StructuralMechanicalSystem {
        try check(policy)
        let declarations: Int
        do {
            declarations = try NumericalWork.sum(draft.gears.count,
                NumericalWork.sum(draft.passiveLaws.count, draft.torques.count))
            let scalarBindings = try NumericalWork.product(policy.coordinates.count, draft.torques.count)
            try work.requireStorage(NumericalWork.sum(scalarBindings,
                NumericalWork.sum(NumericalWork.product(24, policy.coordinates.count),
                    NumericalWork.product(64, declarations))))
            try work.chargeOperations(declarations)
        } catch { throw .numerical(error) }
        guard declarations <= policy.maximumDeclarations,
              policy.coordinates.count <= policy.transmission.maximumCoordinates else { throw .capacityExceeded }
        guard policy.transmission.expectedModelRevision == draft.descriptor.revision,
              policy.transmission.expectedLayoutRevision == draft.descriptor.revision else { throw .invalidInput }
        let model: CompiledMechanicalModel
        do { model = try mechanical.compile(draft.descriptor, policy: compilationPolicy) }
        catch { throw .compilation(error) }
        guard model.stamp == ModelStamp(identity: draft.descriptor.identity, revision: draft.descriptor.revision),
              model.descriptor.root == draft.descriptor.root,
              model.descriptor.rootBase == draft.descriptor.rootBase,
              model.descriptor.rootAuthority == draft.descriptor.rootAuthority,
              model.descriptor.worldFrame == draft.descriptor.worldFrame,
              model.descriptor.initialState == draft.descriptor.initialState,
              model.descriptor.bodies.sorted(by: { $0.id.key < $1.id.key }) == draft.descriptor.bodies.sorted(by: { $0.id.key < $1.id.key }),
              model.descriptor.joints.sorted(by: { $0.record.id.key < $1.record.id.key }) == draft.descriptor.joints.sorted(by: { $0.record.id.key < $1.record.id.key }) else {
            throw .compilation(.one(.producerValidationFailure, .input,
                message: "Mechanical supplier changed the structural source records."))
        }
        let n = model.tree.layout.velocityCount
        guard n > 0, n == policy.coordinates.count, n <= policy.transmission.maximumCoordinates,
              model.tree.rootBase == .fixed, model.descriptor.rootAuthority == .fixed,
              model.tree.layout.positionCount == n, model.tree.layout.joints.count == n,
              model.descriptor.initialState.time >= policy.minimumTime,
              model.descriptor.initialState.time <= policy.maximumTime else { throw .invalidInput }
        // The actual affine mechanism consumer requires spatial inertia even for its
        // static root. Reject missing source physics before returning its composition.
        for body in model.descriptor.bodies {
            try charge(1, work: &work)
            guard case .spatial(let record) = body, record.inertia != nil else { throw .missingInertia(body.id) }
        }
        var records: [EntityID: MechanicalJoint] = [:]
        for record in model.descriptor.joints {
            try charge(1, work: &work); records[record.record.id] = record
        }
        var inputs: [EntityID: StructuralCoordinateBinding] = [:], numeric: Set<UInt64> = []
        for binding in policy.coordinates {
            try charge(1, work: &work)
            guard inputs[binding.joint] == nil else { throw .invalidBinding(binding.joint) }
            guard numeric.insert(binding.coordinateID).inserted else { throw .duplicateNumericIdentity(binding.coordinateID) }
            inputs[binding.joint] = binding
        }
        var ordered: [StructuralCoordinateBinding] = [], dimensions: [PhysicalDimension] = []
        var kinds: [ScalarCoordinateKind] = [], indices: [EntityID: Int] = [:]
        ordered.reserveCapacity(n); dimensions.reserveCapacity(n); kinds.reserveCapacity(n)
        for (index, entry) in model.tree.layout.joints.enumerated() {
            try check(policy); try charge(1, work: &work)
            guard let wrapper = records[entry.joint], let binding = inputs[entry.joint] else { throw .missingJoint(entry.joint) }
            let joint = wrapper.record
            // FIXME(INCOMPLETE_IMPLEMENTATION): Fixed, floating, coupled/quaternion and
            // prescribed charts reach here. Actual q-v/effort routing is required before
            // they may enter this scalar affine producer/consumer composition.
            guard entry.positions.count == 1, entry.velocities.count == 1,
                  entry.positions.start == index, entry.velocities.start == index,
                  wrapper.authority == .dynamicState,
                  joint.manifold.kind == .revolute || joint.manifold.kind == .prismatic,
                  case .fixed = joint.parentAnchor.placement, case .fixed = joint.childAnchor.placement else {
                throw .unsupportedJoint(entry.joint)
            }
            guard model.descriptor.initialState.q[index] >= binding.minimumPosition,
                  model.descriptor.initialState.q[index] <= binding.maximumPosition else { throw .invalidBinding(entry.joint) }
            ordered.append(binding); indices[entry.joint] = index
            dimensions.append(joint.manifold.kind == .revolute ? .angle : .length)
            kinds.append(joint.manifold.kind == .revolute ? .rotation : .translation)
        }
        let layout: ConstraintCoordinateLayout
        do {
            layout = try ConstraintCoordinateLayout(coordinateIDs: ordered.map { $0.coordinateID },
                dimensions: dimensions, scales: ordered.map { $0.scale }, timeScale: policy.timeScale,
                revision: model.stamp.revision)
        } catch { throw .constraint(error) }
        let network = try compileGears(draft, model: model, records: records, indices: indices,
            layout: layout, ordered: ordered, policy: policy, work: &work, transmissionWork: &transmissionWork)
        let passive = try compilePassive(draft, model: model, layout: layout, indices: indices,
            policy: policy, work: &work, loadWork: &loadWork)
        let motors = try compileMotors(draft, model: model, records: records, indices: indices,
            kinds: kinds, policy: policy, work: &work, actuationWork: &actuationWork)
        try check(policy)
        return StructuralMechanicalSystem(source: draft, model: model, coordinateBindings: ordered,
            layout: layout, transmission: network, passiveCatalog: passive,
            passiveSelection: passive == nil ? nil : policy.loadSelection,
            motors: motors.bindings, drive: motors.drive)
    }

    private func compileGears(_ draft: StructuralPhysicsDraft, model: CompiledMechanicalModel,
        records: [EntityID: MechanicalJoint], indices: [EntityID: Int], layout: ConstraintCoordinateLayout,
        ordered: [StructuralCoordinateBinding], policy: StructuralSystemPolicy,
        work: inout NumericalWork, transmissionWork: inout NumericalWork
    ) throws(StructuralSystemFailure) -> CompiledTransmissionNetwork? {
        if draft.gears.isEmpty { return nil }
        guard draft.gears.count <= policy.transmission.maximumRelations else { throw .capacityExceeded }
        var ports: [TransmissionPortBinding] = [], portIndices: [EntityID: Int] = [:]
        var relations: [TransmissionRelation] = [], numeric: Set<UInt64> = []
        relations.reserveCapacity(draft.gears.count)
        for gear in draft.gears {
            try check(policy); try charge(1, work: &work)
            guard numeric.insert(gear.rowID).inserted else { throw .duplicateNumericIdentity(gear.rowID) }
            for id in [gear.first, gear.second] where portIndices[id] == nil {
                guard ports.count < policy.transmission.maximumPorts else { throw .capacityExceeded }
                guard let wrapper = records[id], let index = indices[id] else { throw .missingJoint(id) }
                let joint = wrapper.record
                guard joint.manifold.kind == .revolute else { throw .unsupportedJoint(id) }
                try charge(model.descriptor.bodies.count, work: &work)
                // FIXME(INCOMPLETE_IMPLEMENTATION): Gears on moving supports require a
                // relative support-coordinate/power law. This compiler currently binds
                // world-static admitted parent supports and never freezes a moving axis.
                guard let parent = model.descriptor.bodies.first(where: { $0.id == joint.parentBody }),
                      parent.mode == .static else { throw .movingGearSupport(id) }
                let pose: RigidTransform
                do { pose = try model.initialSnapshot.frame(joint.parentAnchor.frame).motion.pose }
                catch { throw .invalidBinding(id) }
                let port: TransmissionPortBinding
                do {
                    port = try TransmissionPortBinding(coordinateIndex: index,
                        coordinateID: ordered[index].coordinateID, body: joint.childBody, joint: id,
                        frame: model.tree.worldFrame, manifold: joint.manifold, jointToReference: pose,
                        layoutRevision: layout.revision, modelRevision: model.stamp.revision)
                } catch { throw .transmission(error) }
                portIndices[id] = ports.count; ports.append(port)
            }
            guard let first = portIndices[gear.first], let second = portIndices[gear.second] else { throw .invalidBinding(gear.id) }
            let kind: TransmissionRelationKind = gear.internalMesh
                ? .internalGear(first: first, second: second, firstTeeth: gear.firstTeeth,
                    secondTeeth: gear.secondTeeth, phase: gear.phaseRadians, phaseScale: gear.phaseScaleRadians)
                : .externalGear(first: first, second: second, firstTeeth: gear.firstTeeth,
                    secondTeeth: gear.secondTeeth, phase: gear.phaseRadians, phaseScale: gear.phaseScaleRadians)
            relations.append(TransmissionRelation(id: gear.rowID, kind: kind))
        }
        do {
            let network = try AffineTransmissionCompiler().compile(id: policy.networkID, layout: layout,
                ports: ports, relations: relations, minimumPosition: ordered.map { $0.minimumPosition },
                maximumPosition: ordered.map { $0.maximumPosition }, minimumTime: policy.minimumTime,
                maximumTime: policy.maximumTime, policy: policy.transmission, work: &transmissionWork)
            // Zero effort is used solely to check actual phase/rate/power, never to infer reaction forces.
            _ = try AffineTransmissionOperator().idealEfforts(network,
                position: model.descriptor.initialState.q, velocity: model.descriptor.initialState.v,
                normalizedEnergyMultipliers: [Double](repeating: 0, count: relations.count),
                policy: policy.transmission, work: &transmissionWork)
            return network
        } catch { throw .transmission(error) }
    }

    private func compilePassive(_ draft: StructuralPhysicsDraft, model: CompiledMechanicalModel,
        layout: ConstraintCoordinateLayout, indices: [EntityID: Int], policy: StructuralSystemPolicy,
        work: inout NumericalWork, loadWork: inout LoadWork
    ) throws(StructuralSystemFailure) -> StationaryLoadCatalog? {
        if draft.passiveLaws.isEmpty { return nil }
        guard draft.passiveLaws.count <= policy.loadCapacity.maximumTermsPerProgram else { throw .capacityExceeded }
        var terms: [StationaryScalarLoad] = [], numeric: Set<UInt64> = []
        terms.reserveCapacity(draft.passiveLaws.count)
        for source in draft.passiveLaws {
            try check(policy); try charge(1, work: &work)
            guard numeric.insert(source.termID).inserted else { throw .duplicateNumericIdentity(source.termID) }
            guard let index = indices[source.joint] else { throw .missingJoint(source.joint) }
            guard layout.dimensions[index] == (source.law.coordinateKind == .rotation ? .angle : .length) else {
                throw .invalidBinding(source.joint)
            }
            do {
                _ = try ScalarLoadEvaluator().evaluate(source.law, coordinate: model.descriptor.initialState.q[index],
                    rate: model.descriptor.initialState.v[index], work: &loadWork)
            } catch { throw .loads(error) }
            terms.append(StationaryScalarLoad(id: source.termID, coordinateID: layout.coordinateIDs[index], law: source.law))
        }
        do {
            return try StationaryLoadCatalog(model: model, layout: layout,
                programs: [StationaryLoadProgram(id: policy.loadSelection.programID, revision: policy.loadSelection.revision,
                    gravity: nil, terms: terms)], capacity: policy.loadCapacity)
        } catch { throw .stationary(error) }
    }

    private func compileMotors(_ draft: StructuralPhysicsDraft, model: CompiledMechanicalModel,
        records: [EntityID: MechanicalJoint], indices: [EntityID: Int], kinds: [ScalarCoordinateKind],
        policy: StructuralSystemPolicy, work: inout NumericalWork, actuationWork: inout ActuationWork
    ) throws(StructuralSystemFailure) -> (bindings: [StructuralMotorBinding], drive: [Double]) {
        let n = kinds.count
        var output: [StructuralMotorBinding] = [], drive = [Double](repeating: 0, count: n)
        output.reserveCapacity(draft.torques.count)
        for source in draft.torques {
            try check(policy); try charge(n, work: &work)
            guard let index = indices[source.joint], let record = records[source.joint] else { throw .missingJoint(source.joint) }
            guard record.record.manifold.kind == .revolute else { throw .unsupportedJoint(source.joint) }
            var gradient = [Double](repeating: 0, count: n); gradient[index] = 1
            let transfer: AffineTransmission, response: TransmissionResponse
            do {
                transfer = try AffineTransmission(model: model.stamp, frame: model.tree.worldFrame,
                    outputCoordinate: .rotation, inputCoordinates: kinds, gradient: gradient,
                    prescribedRate: 0, work: &actuationWork)
                response = try ReferenceActuationTransmitter(mapper: LoadMapper()).affine(transfer,
                    model: model.stamp, frame: model.tree.worldFrame, effort: source.torqueNm,
                    rate: model.descriptor.initialState.v, tolerance: policy.motorPowerTolerance,
                    work: &actuationWork, numerical: &work)
            } catch { throw .actuation(error) }
            for i in 0..<n {
                try charge(1, work: &work); drive[i] += response.efforts[i]
                guard drive[i].isFinite else { throw .invalidBinding(source.id) }
            }
            output.append(StructuralMotorBinding(declaration: source, rotor: record.record.childBody,
                stator: record.record.parentBody, transfer: transfer))
        }
        return (output, drive)
    }

    private func charge(_ count: Int, work: inout NumericalWork) throws(StructuralSystemFailure) {
        do { try work.chargeOperations(count) } catch { throw .numerical(error) }
    }
    private func check(_ policy: StructuralSystemPolicy) throws(StructuralSystemFailure) {
        guard !Task.isCancelled, !policy.transmission.isCancelled() else { throw .transmission(.cancelled) }
    }
}
