import SwiftMechanics

internal enum AttachmentsQualificationFixtures {
    typealias E = AttachmentsQualificationError
    enum Mode: Equatable { case floating, spherical, prescribed }
    struct Input: Sendable {
        let rigid: AttachmentRigidSource
        let material: DeformingSurfaceSnapshot
        let attachment: RigidMaterialAttachment
        let policy: AttachmentPolicy
        let surfacePolicy: DeformingContactPolicy
    }
    static func require(_ value: Bool, _ label: String) throws(E) { guard value else { throw .assertion(label) } }
    static func near(_ a: Double, _ b: Double, _ label: String) throws(E) {
        try require(a.isFinite && b.isFinite && abs(a-b)<=1e-8*max(1,max(abs(a),abs(b))),label)
    }
    static func near(_ a: Vector3, _ b: Vector3, _ label: String) throws(E) {
        try near(a.x,b.x,label+" x");try near(a.y,b.y,label+" y");try near(a.z,b.z,label+" z")
    }
    static func build<T>(_ body: () throws -> T) throws(E) -> T {
        do { return try body() }
        catch let e as E { throw e }
        catch let e as AttachmentError { throw .attachment(e) }
        catch let e as CoreError { throw .core(e) }
        catch let e as JointError { throw .joint(e) }
        catch let e as ModelError { throw .model(e) }
        catch let e as FlexibleError { throw .flexible(e) }
        catch let e as MaterialError { throw .material(e) }
        catch let e as NumericalError { throw .numerical(e) }
        catch let e as DeformingContactError { throw .surface(e) }
        catch { throw .unexpectedSupplierFailure }
    }
    static func v(_ x: Double, _ y: Double, _ z: Double) throws(E) -> Vector3 { try build { try Vector3(x,y,z) } }
    static func dot(_ a: Vector3, _ b: Vector3) -> Double { a.x*b.x+a.y*b.y+a.z*b.z }
    static func cross(_ a: Vector3, _ b: Vector3) throws(E) -> Vector3 { try v(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    static func add(_ a: Vector3, _ b: Vector3) throws(E) -> Vector3 { try v(a.x+b.x,a.y+b.y,a.z+b.z) }
    static func id(_ kind: EntityKind, _ key: String) throws(E) -> EntityID { try build { try EntityID(kind:kind,key:key) } }
    static func work(storage: Int = 100_000, operations: Int = 10_000_000) throws(E) -> NumericalWork {
        try build { NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0)) }
    }
    static func jointPolicy() throws(E) -> JointEvaluationPolicy {
        try build { try JointEvaluationPolicy(quaternionTolerance:NumericalTolerance(absolute:1e-10,relative:1e-10),chartRankRelative:1e-10,characteristicLengthMeters:1) }
    }
    static func policy(_ rigidCount: Int, rows: Int = 10, scalars: Int = 100_000, bytes: Int = 256,
                       scaleCount: Int? = nil, cancelled: @escaping @Sendable () -> Bool = {false}) throws(E) -> AttachmentPolicy {
        try build { try AttachmentPolicy(maximumAttachments:4,maximumRows:rows,maximumScalars:scalars,maximumIdentifierBytes:bytes,
            rankColumnScales:[Double](repeating:1,count:scaleCount ?? rigidCount+12),generalizedEffortTolerances:[Double](repeating:1e-8,count:rigidCount),
            rankTolerance:1e-10,directionTolerance:1e-10,velocityTolerance:1e-8,accelerationTolerance:1e-8,gapTolerance:1e-8,rateTolerance:1e-8,
            forceTolerance:1e-8,momentTolerance:1e-8,powerTolerance:1e-8,isCancelled:cancelled) }
    }
    static func surfacePolicy(cancelled: @escaping @Sendable () -> Bool = {false}) throws(E) -> DeformingContactPolicy {
        try build { try DeformingContactPolicy(maximumNodes:10,maximumCells:10,maximumFaces:10,maximumContacts:4,maximumIdentifierBytes:256,
            minimumVolume:1e-12,minimumDoubleArea:1e-12,lengthTolerance:1e-10,barycentricInterior:1e-7,
            forceTolerance:1e-8,momentTolerance:1e-8,powerTolerance:1e-8,rotationTolerance:1e-10,isCancelled:cancelled) }
    }
    static func body(_ name: String, pose: RigidTransform = .identity) throws(E) -> KinematicBody {
        try build {
            let mass=try MassProperties3D(mass:1,centerOfMass:.zero,inertiaAtCenter:.identity,
                policy:InertiaValidationPolicy(symmetry:NumericalTolerance(absolute:0,relative:0),physicalityRelative:0))
            return KinematicBody(body:try BodyRecord3D(id:id(.body,name),frame:id(.frame,name+"-frame"),mode:.dynamic,bodyToWorld:pose,
                representations:BodyRepresentations(),inertia:InertialRepresentation3D(properties:mass,provenance:SourceProvenance(source:"analytic attachment body",revision:7),quality:.exact)))
        }
    }
    static func rigid(_ mode: Mode) throws(E) -> AttachmentRigidSource {
        try build {
            let root=try body("root",pose:RigidTransform(rotation:.identity,translation:v(2,0,0)))
            var bodies=[root],joints:[JointRecord]=[],anchors:[PrescribedAnchorState]=[]
            let q:[Double],velocities:[Double],base:BaseLayout
            switch mode {
            case .floating:q=[2,0,0,1,0,0,0];velocities=[9,6,0,0,0,3];base = .spatialFloating
            case .spherical,.prescribed:
                let child=try body("child");bodies.append(child);base = .fixed
                let parentFrame=try id(.frame,"parent-anchor")
                let placement: AnchorPlacement
                let specification: JointSpecification
                if mode == .spherical {
                    q=[1,0,0,0];velocities=[0,0,3];placement = .fixed(.identity);specification = .spherical
                } else {
                    // Prescribed root is stationary at origin for the analytic moving-anchor case.
                    bodies[0]=try body("root")
                    q=[2];velocities=[5];placement = .prescribed;specification = .prismatic(axis:.unitX)
                    anchors=[try PrescribedAnchorState(frame:parentFrame,time:0.5,motion:FrameMotion(pose:.identity,
                        velocity:SpatialMotion(angular:v(0,0,3),linear:v(4,0,0)),acceleration:SpatialMotion(angular:.zero,linear:v(6,0,0))))]
                }
                joints=[try JointRecord(id:id(.joint,"joint"),parentBody:root.id,childBody:child.id,
                    parentAnchor:JointAnchor(frame:parentFrame,placement:placement),childAnchor:JointAnchor(frame:id(.frame,"child-anchor"),placement:.fixed(.identity)),
                    manifold:JointManifold(specification))]
            }
            let tree=try KinematicTree(bodies:bodies,joints:joints,root:root.id,rootBase:base,worldFrame:id(.frame,"world"),revision:7,
                capacity:KinematicCapacity(maximumBodies:4,maximumVelocities:6,maximumJacobianScalars:144))
            let state=try KinematicState(revision:7,time:0.5,q:q,v:velocities,acceleration:[Double](repeating:0,count:velocities.count),prescribedAnchors:anchors)
            return try AttachmentRigidSource(tree:tree,state:state,policy:jointPolicy())
        }
    }
    static func surface() throws(E) -> MaterialSurface {
        try build {
            let origin=try SourceProvenance(source:"qualified attachment Tet4",revision:7),materialID=try id(.material,"material")
            let law=try PolynomialHyperelasticity(elasticity:IsotropicElasticity(bulkModulus:12,shearModulus:3),nonlinearModulus:0,
                domain:StrainDomain(maximumStrainNorm:2,minimumVolumeRatio:0.1))
            let material=try FlexibleMaterial(identifier:materialID,source:origin,law:law,referenceDensity:6,massDampingRate:0)
            let nodes=[FlexibleNode(identifier:10,referencePosition:.zero),FlexibleNode(identifier:11,referencePosition:.unitX),
                FlexibleNode(identifier:12,referencePosition:.unitY),FlexibleNode(identifier:13,referencePosition:.unitZ)]
            let cell=try TetrahedronCell(identifier:50,nodes:[0,1,2,3],material:materialID,source:origin)
            let raw=try TetrahedralMesh(frame:id(.frame,"world"),revision:7,source:origin,nodes:nodes,cells:[cell],materials:[material])
            var work=try Self.work()
            let validator:any TetrahedralMeshValidating=TetrahedralMeshValidator()
            let mesh=try validator.validate(raw,admission:MeshAdmission(maximumNodes:10,maximumCells:10,maximumMaterials:2,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12),work:&work)
            let updater:any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater()
            return try updater.extract(mesh,body:ModelReference(id:id(.body,"material-body"),revision:7),policy:surfacePolicy(),work:&work)
        }
    }
    static func snapshot(_ surface: MaterialSurface, mode: Mode, time: Double = 0.5, revision: UInt64 = 4,
                         shift: Vector3 = .zero) throws(E) -> DeformingSurfaceSnapshot {
        try build {
            let base=try [v(2.35,-0.6,0),v(3.35,-0.6,0),v(2.85,1.4,0),v(2.35,-0.6,0.5)]
            var positions:[Vector3]=[],velocities:[Vector3]=[]
            for x in base {
                positions.append(try add(x,shift))
                velocities.append(try v((mode == .spherical ? 0 : 9)-3*x.y,3*(x.x-(mode == .spherical ? 2 : 0)),0))
            }
            let state=NodalState(frame:surface.mesh.mesh.frame,meshRevision:7,nodeIdentifiers:[10,11,12,13],positions:positions,velocities:velocities)
            var work=try Self.work();let updater:any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater()
            return try updater.update(surface,state:state,geometryRevision:revision,time:time,previous:nil,policy:surfacePolicy(),work:&work)
        }
    }
    static func attachment(_ source: AttachmentRigidSource, site: AttachmentMaterialSite, identifier: String = "interface",
                           owner: String = "boundary", revision: UInt64 = 7, dofs: AttachmentDegreesOfFreedom = .pointTranslation(directions:[.unitX,.unitY,.unitZ]),
                           frame: EntityID? = nil) throws(E) -> RigidMaterialAttachment {
        guard let body=source.snapshot.tree.bodies.last else { throw .assertion("Actual admitted tree requires a body") }
        return try build { try RigidMaterialAttachment(identifier:identifier,boundaryOwner:owner,rigidBody:body.id,rigidFrame:frame ?? body.frame,
            rigidRevision:revision,bodyLocalPoint:.unitX,site:site,degreesOfFreedom:dofs) }
    }
    static func input(_ mode: Mode) throws(E) -> Input {
        let source=try rigid(mode),material=try snapshot(surface(),mode:mode),p=try policy(source.state.v.count),sp=try surfacePolicy()
        var work=try Self.work();let solver:any RigidMaterialAttachmentComputing=TetrahedralPointAttachments()
        let site=try build { try solver.materialSite(SurfaceMaterialPoint(feature:SurfaceFeatureID(cell:50,oppositeNode:3),barycentric:[0.2,0.3,0.5],sumTolerance:1e-10),
            snapshot:material,policy:p,surfacePolicy:sp,work:&work) }
        return Input(rigid:source,material:material,attachment:try attachment(source,site:site),policy:p,surfacePolicy:sp)
    }
    static func query(_ i: Input) throws(E) -> RigidMaterialAttachmentQuery {
        var w=try work();let service:any RigidMaterialAttachmentComputing=TetrahedralPointAttachments()
        return try build { try service.query([i.attachment],boundaryOwner:"boundary",existingBoundaryRows:[],rigid:i.rigid,material:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w) }
    }
    static func forces(_ i: Input, _ q: RigidMaterialAttachmentQuery) throws(E) -> AttachmentForceProposal {
        var w=try work();let service:any RigidMaterialAttachmentComputing=TetrahedralPointAttachments()
        return try build { try service.forces(q,multipliers:[2,-3,4],currentRigid:i.rigid,currentMaterial:i.material,policy:i.policy,surfacePolicy:i.surfacePolicy,work:&w) }
    }
    static func expect(_ wanted: AttachmentError, _ body: () throws(AttachmentError) -> Void) throws(E) {
        do { try body() } catch {
            // Compare exact public typed causes without reflection or dynamic type queries.
            if matches(error,errorWanted:wanted) { return }
            throw .attachment(error)
        }
        throw .assertion("Expected typed attachment refusal")
    }
    static func matches(_ actual: AttachmentError, errorWanted wanted: AttachmentError) -> Bool {
        switch (actual,wanted) {
        case (.invalidInput,.invalidInput),(.nonFinite,.nonFinite),(.capacityExceeded,.capacityExceeded),(.cancelled,.cancelled),
             (.staleSite,.staleSite),(.staleSource,.staleSource),(.staleGeometry,.staleGeometry),(.staleLayout,.staleLayout),
             (.frameMismatch,.frameMismatch),(.timeMismatch,.timeMismatch),(.boundaryOwnershipMismatch,.boundaryOwnershipMismatch),
             (.duplicateAttachment,.duplicateAttachment),(.rankDeficient,.rankDeficient),(.overconstrained,.overconstrained),
             (.physicalResidual,.physicalResidual),(.unsupportedOrientation,.unsupportedOrientation),
             (.joint(.stateRevisionMismatch),.joint(.stateRevisionMismatch)),(.joint(.invalidCoordinateCount),.joint(.invalidCoordinateCount)),
             (.surface(.cancelled),.surface(.cancelled)): return true
        case (.joint(.missingDerivativeData(let actual)),.joint(.missingDerivativeData(let wanted))):return actual==wanted
        case (.numerical(.resourceLimit(resource:let ar,limit:let al)),.numerical(.resourceLimit(resource:let wr,limit:let wl))):return ar==wr && al==wl
        default:return false
        }
    }
}
