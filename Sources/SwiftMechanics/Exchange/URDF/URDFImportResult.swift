public struct URDFImportResult: URDFMechanicalConfiguring {
    public enum DynamicsAvailability: Sendable { case available, missingSuppliedInertia, zeroVelocitiesUnsupported }
    public let robotName: String
    public let model: CompiledMechanicalModel
    public let geometries: [URDFGeometryRecord]
    public let collisions: [URDFCollisionBinding]
    public let assets: [URDFAssetReference]
    public let losses: [URDFLoss]
    /// The admitted input is immutable and independent of later runtime states.
    public let document: XMLDocument
    public let dynamicsAvailability: DynamicsAvailability
    internal init(robotName: String, model: CompiledMechanicalModel, geometries: [URDFGeometryRecord],
                  collisions: [URDFCollisionBinding], assets: [URDFAssetReference], losses: [URDFLoss], document: XMLDocument,
                  dynamicsAvailability: DynamicsAvailability) {
        self.robotName = robotName; self.model = model; self.geometries = geometries
        self.collisions = collisions; self.assets = assets; self.losses = losses; self.document = document
        self.dynamicsAvailability = dynamicsAvailability
    }

    public func dynamicsInput(state: CompiledKinematicState, gravity: AffineGravity?,
                              bodyWrenches: [BodyWrenchContribution], generalizedForces: [GeneralizedForceContribution],
                              work: inout URDFWork) throws(URDFFailure) -> RigidDynamicsInput {
        do {
            try work.charge(1)
            guard case .available = dynamicsAvailability else { throw URDFFailure(.unsupported("complete spatial dynamics inventory/V0")) }
            let snapshot = try model.evaluate(state)
            try work.allocate(snapshot.bodies.count, stride: MemoryLayout<RigidBodyInertia>.stride)
            var inertias: [RigidBodyInertia] = []; inertias.reserveCapacity(snapshot.bodies.count)
            for body in snapshot.bodies {
                var found: InertialRepresentation3D? = nil
                for candidate in model.descriptor.bodies {
                    try work.charge(1)
                    if candidate.id == body.body, case .spatial(let record) = candidate { found = record.inertia; break }
                }
                guard let found else { throw URDFFailure(.missing("complete dynamics inertia")) }
                inertias.append(try RigidBodyInertia(body: body.body, frame: body.bodyFrame, properties: found.properties))
            }
            try work.charge(state.state.v.count)
            let input = try RigidDynamicsInput(snapshot: snapshot, velocity: state.state.v, inertias: inertias,
                gravity: gravity, bodyWrenches: bodyWrenches, generalizedForces: generalizedForces)
            try work.charge(1)
            return input
        } catch let error as URDFFailure { throw error }
        catch let error as CompilationFailure { throw URDFFailure(.compilation(error)) }
        catch let error as DynamicsError { throw URDFFailure(.dynamics(error)) }
        catch { throw URDFFailure(.unexpectedProducer) }
    }
}
