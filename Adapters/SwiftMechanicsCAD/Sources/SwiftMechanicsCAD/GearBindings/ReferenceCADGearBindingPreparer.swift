import CADIR
import CADKernel
import SwiftMechanics

public struct ReferenceCADGearBindingPreparer: CADGearBindingPreparing {
    public init() {}

    public func bind(_ request: CADGearPairRequest, geometry: CADGeometryAdmission,
                     model: CompiledMechanicalModel, state: CompiledKinematicState,
                     layout: ConstraintCoordinateLayout, policy: CADGearBindingPolicy,
                     transmissionPolicy: TransmissionPolicy, work: inout CADAdapterWork,
                     transmissionWork: inout NumericalWork) throws(CADGearBindingError) -> CADGearPairBinding {
        try gearCAD { () throws(CADAdapterError) in try work.charge() }
        guard request.source == geometry.identity else { throw .staleSource }
        guard request.model == model.stamp, state.stamp == model.stamp else { throw .staleModel }
        guard request.first.joint != request.second.joint,
              request.first.occurrenceID != request.second.occurrenceID else { throw .duplicateShaft }
        // FIXME(INCOMPLETE_IMPLEMENTATION): Resolved tooth contact is not supplied by this ideal
        // binding path. Callers requesting it are refused until original tooth/contact force,
        // error and failure acceptance are available; an ideal ratio is not completion.
        guard request.fidelity == .idealExternalSpur else { throw .unsupportedFidelity }
        try preflight(request, model: model, layout: layout, policy: policy, work: &work)
        guard model.descriptor.rootBase == .fixed, model.descriptor.rootAuthority == .fixed,
              state.state.prescribedAnchors.isEmpty,
              state.state == model.descriptor.initialState,
              model.tree.layout.positionCount == model.tree.layout.velocityCount,
              layout.coordinateIDs.count == model.tree.layout.positionCount,
              layout.revision == model.stamp.revision,
              state.state.time >= request.minimumTime, state.state.time <= request.maximumTime else {
            throw .unsupportedDomain
        }
        for body in model.descriptor.bodies {
            try gearCAD { () throws(CADAdapterError) in try work.charge() }
            guard case .spatial = body else { throw .unsupportedDomain }
        }
        for joint in model.descriptor.joints {
            try gearCAD { () throws(CADAdapterError) in try work.charge() }
            guard joint.authority == .dynamicState,
                  case .fixed = joint.record.parentAnchor.placement,
                  case .fixed = joint.record.childAnchor.placement else { throw .unsupportedDomain }
        }
        let snapshot: KinematicSnapshot
        do { snapshot = try model.evaluate(state) } catch { throw .compilation(error) }
        let first = try shaft(request.first, geometry: geometry, model: model, snapshot: snapshot,
            state: state, layout: layout, policy: policy, work: &work)
        let second = try shaft(request.second, geometry: geometry, model: model, snapshot: snapshot,
            state: state, layout: layout, policy: policy, work: &work)
        try compatibility(first.gear, second.gear, policy: policy)
        guard let firstTeeth = UInt32(exactly: first.gear.toothCount), firstTeeth > 0,
              let secondTeeth = UInt32(exactly: second.gear.toothCount), secondTeeth > 0 else { throw .invalidInput }
        let network: CompiledTransmissionNetwork
        do {
            network = try AffineTransmissionCompiler().compile(id: request.networkID, layout: layout,
                ports: [first.port, second.port], relations: [TransmissionRelation(id: request.relationID,
                    kind: .externalGear(first: 0, second: 1, firstTeeth: firstTeeth,
                        secondTeeth: secondTeeth, phase: request.phase, phaseScale: request.phaseScale))],
                minimumPosition: request.minimumPosition, maximumPosition: request.maximumPosition,
                minimumTime: request.minimumTime, maximumTime: request.maximumTime,
                policy: transmissionPolicy, work: &transmissionWork)
            // Original physical phase and speed acceptance, with no fabricated load multiplier.
            _ = try AffineTransmissionOperator().idealEfforts(network, position: state.state.q,
                velocity: state.state.v, normalizedEnergyMultipliers: [0],
                policy: transmissionPolicy, work: &transmissionWork)
        } catch { throw .transmission(error) }
        try gearCAD { () throws(CADAdapterError) in try work.poll() }
        return CADGearPairBinding(admission: _CADGearPairAdmission(geometry: geometry, model: model,
            state: state, first: first.gear, second: second.gear, firstEndFace: first.face,
            secondEndFace: second.face, request: request, network: network))
    }

    private func preflight(_ request: CADGearPairRequest, model: CompiledMechanicalModel,
                           layout: ConstraintCoordinateLayout, policy: CADGearBindingPolicy,
                           work: inout CADAdapterWork) throws(CADGearBindingError) {
        var records = 0
        for count in [model.descriptor.bodies.count, model.descriptor.joints.count,
                      model.tree.bodies.count, model.tree.joints.count, layout.coordinateIDs.count,
                      request.minimumPosition.count, request.maximumPosition.count] {
            let sum = records.addingReportingOverflow(count)
            guard !sum.overflow, sum.partialValue <= policy.maximumModelRecords else { throw .capacityExceeded }
            records = sum.partialValue
        }
        var metadata = 0
        func add(_ string: String) throws(CADGearBindingError) {
            let sum = metadata.addingReportingOverflow(string.utf8.count)
            guard !sum.overflow, sum.partialValue <= policy.maximumMetadataBytes else { throw .capacityExceeded }
            metadata = sum.partialValue
        }
        try add(request.model.identity)
        try add(request.first.occurrenceID); try add(request.second.occurrenceID)
        for body in model.descriptor.bodies { try add(body.id.key); try add(body.frame.key) }
        for joint in model.tree.joints {
            try add(joint.id.key); try add(joint.parentBody.key); try add(joint.childBody.key)
            try add(joint.parentAnchor.frame.key); try add(joint.childAnchor.frame.key)
        }
        try gearCAD { () throws(CADAdapterError) in try work.charge(records) }
    }

    private func shaft(_ request: CADGearShaftRequest, geometry: CADGeometryAdmission,
                       model: CompiledMechanicalModel, snapshot: KinematicSnapshot,
                       state: CompiledKinematicState, layout: ConstraintCoordinateLayout,
                       policy: CADGearBindingPolicy, work: inout CADAdapterWork)
        throws(CADGearBindingError) -> (gear: CADInvoluteGearWitness, face: CADSurfaceWitness, port: TransmissionPortBinding) {
        let query: any CADInvoluteGearQuerying = geometry
        let gear = try gearCAD { () throws(CADAdapterError) in try query.involuteGear(occurrenceID: request.occurrenceID,
            expected: geometry.identity, work: &work) }
        guard request.endFace.occurrenceID == request.occurrenceID else { throw .wrongAnchor }
        guard let index = model.tree.joints.firstIndex(where: { $0.id == request.joint }) else { throw .missingShaft }
        try gearCAD { () throws(CADAdapterError) in try work.charge(model.tree.joints.count) }
        let joint = model.tree.joints[index], range = model.tree.layout.joints[index]
        guard joint.parentBody == model.tree.bodies[0].id,
              joint.manifold.kind == .revolute, joint.manifold.positionCount == 1,
              joint.manifold.velocityCount == 1, joint.manifold.orderedAxes.count == 1,
              range.positions.count == 1, range.velocities.count == 1,
              range.positions.start == range.velocities.start,
              layout.dimensions[range.positions.start] == .angle else { throw .unsupportedDomain }
        guard gear.occurrence.body == joint.childBody,
              let body = snapshot.bodies.first(where: { $0.body == joint.childBody }),
              body.bodyFrame == gear.occurrence.frame else { throw .wrongOccurrence }
        let worldParent = snapshot.joints[index].parentAnchor.motion.pose
        let axis = try gearCore { () throws(CoreError) in try worldParent.transforming(direction: joint.manifold.orderedAxes[0].direction) }
        guard try distance(joint.manifold.orderedAxes[0].direction, .unitZ) <= policy.directionTolerance,
              try distance(axis, gear.worldAxis) <= policy.directionTolerance else { throw .incompatibleAxis }
        try samePose(gear.occurrence.placement, body.motion.pose, policy: policy)
        guard try radialDistance(gear.worldOrigin, from: worldParent.translation, axis: axis) <= policy.lengthTolerance else {
            throw .incompatiblePlacement
        }
        let angle = state.state.q[range.positions.start] + request.mountingPhase
        guard angle.isFinite else { throw .invalidInput }
        let rotation = try gearCore { () throws(CoreError) in try UnitQuaternion(axis: .unitZ, angle: angle) }
        let zero = try gearCore { () throws(CoreError) in try worldParent.transforming(direction: rotation.rotating(.unitX)) }
        guard try distance(zero, gear.worldToothZero) <= policy.directionTolerance else { throw .incompatibleMountingPhase }
        let face = try gearCAD { () throws(CADAdapterError) in try query.surfaceAnchor(request.endFace, nearestTo: gear.localOrigin,
            expected: geometry.identity, options: SurfaceProjectionOptions(), work: &work) }
        let alignment = try gearCore { () throws(CoreError) in try face.worldOutwardNormal.dot(axis) }
        guard abs(abs(alignment) - 1) <= policy.directionTolerance,
              try radialDistance(face.worldPoint, from: worldParent.translation, axis: axis) <= policy.lengthTolerance else {
            throw .wrongAnchor
        }
        let localDepth = try gearCore { () throws(CoreError) in try face.localPoint.subtracting(gear.localOrigin).dot(.unitZ) }
        guard let width = gear.dimensions[.width],
              min(abs(localDepth), abs(localDepth - width)) <= policy.lengthTolerance else { throw .wrongAnchor }
        let port: TransmissionPortBinding
        do {
            port = try TransmissionPortBinding(coordinateIndex: range.velocities.start,
                coordinateID: layout.coordinateIDs[range.positions.start], body: joint.childBody, joint: joint.id,
                frame: model.tree.worldFrame, manifold: joint.manifold, jointToReference: worldParent,
                layoutRevision: layout.revision, modelRevision: model.stamp.revision)
        } catch { throw .transmission(error) }
        return (gear, face, port)
    }

    private func compatibility(_ first: CADInvoluteGearWitness, _ second: CADInvoluteGearWitness,
                               policy: CADGearBindingPolicy) throws(CADGearBindingError) {
        guard !first.doubleHelical, !second.doubleHelical,
              first.dimensions[.twistAngle] == 0, second.dimensions[.twistAngle] == 0 else { throw .unsupportedFidelity }
        guard let r1 = first.dimensions[.pitchRadius], let r2 = second.dimensions[.pitchRadius],
              let b1 = first.dimensions[.baseRadius], let b2 = second.dimensions[.baseRadius],
              let w1 = first.dimensions[.width], let w2 = second.dimensions[.width],
              first.toothCount > 0, second.toothCount > 0 else { throw .invalidInput }
        guard abs(2 * r1 / Double(first.toothCount) - 2 * r2 / Double(second.toothCount)) <= policy.moduleTolerance else {
            throw .incompatibleModule
        }
        guard abs(b1 / r1 - b2 / r2) <= policy.pressureRatioTolerance else { throw .incompatiblePressure }
        guard try distance(first.worldAxis, second.worldAxis) <= policy.directionTolerance else { throw .incompatibleAxis }
        let delta = try gearCore { () throws(CoreError) in try second.worldOrigin.subtracting(first.worldOrigin) }
        let axial = try gearCore { () throws(CoreError) in try delta.dot(first.worldAxis) }
        let radial = try radialDistance(second.worldOrigin, from: first.worldOrigin, axis: first.worldAxis)
        guard abs(radial - (r1 + r2)) <= policy.lengthTolerance else { throw .incompatibleSpacing }
        guard min(w1, axial + w2) - max(0, axial) > policy.lengthTolerance else { throw .incompatibleSweep }
    }

    private func distance(_ a: Vector3, _ b: Vector3) throws(CADGearBindingError) -> Double {
        try gearCore { () throws(CoreError) in try a.subtracting(b).magnitude() }
    }
    private func radialDistance(_ point: Vector3, from origin: Vector3, axis: Vector3) throws(CADGearBindingError) -> Double {
        try gearCore { () throws(CoreError) in
            let delta = try point.subtracting(origin)
            return try delta.subtracting(axis.scaled(by: delta.dot(axis))).magnitude()
        }
    }
    private func samePose(_ a: RigidTransform, _ b: RigidTransform,
                          policy: CADGearBindingPolicy) throws(CADGearBindingError) {
        guard try distance(a.translation, b.translation) <= policy.lengthTolerance else { throw .incompatiblePlacement }
        for direction in [Vector3.unitX, .unitY, .unitZ] {
            let first = try gearCore { () throws(CoreError) in try a.rotation.rotating(direction) }
            let second = try gearCore { () throws(CoreError) in try b.rotation.rotating(direction) }
            guard try distance(first, second) <= policy.directionTolerance else {
                throw .incompatiblePlacement
            }
        }
    }
}

struct _CADGearPairAdmission: Sendable {
    let geometry: CADGeometryAdmission
    let model: CompiledMechanicalModel
    let state: CompiledKinematicState
    let first: CADInvoluteGearWitness
    let second: CADInvoluteGearWitness
    let firstEndFace: CADSurfaceWitness
    let secondEndFace: CADSurfaceWitness
    let request: CADGearPairRequest
    let network: CompiledTransmissionNetwork
    fileprivate init(geometry: CADGeometryAdmission, model: CompiledMechanicalModel,
                     state: CompiledKinematicState, first: CADInvoluteGearWitness,
                     second: CADInvoluteGearWitness, firstEndFace: CADSurfaceWitness,
                     secondEndFace: CADSurfaceWitness, request: CADGearPairRequest,
                     network: CompiledTransmissionNetwork) {
        self.geometry = geometry; self.model = model; self.state = state
        self.first = first; self.second = second; self.firstEndFace = firstEndFace
        self.secondEndFace = secondEndFace; self.request = request; self.network = network
    }
}
