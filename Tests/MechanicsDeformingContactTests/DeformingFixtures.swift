import MechanicsCore
import MechanicsModel
import MechanicsMaterials
import MechanicsNumerics
import MechanicsFlexible
import MechanicsCollision
import MechanicsContactLaws
import MechanicsDeformingContact
internal enum DeformingFixtures {
    static func work(operations: Int=10_000_000, storage: Int=100_000) throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0)) }
    static func policy(cancelled: Bool=false, faces: Int=100, cells: Int=100, identifiers: Int=100,
                       cancellation: @escaping @Sendable () -> Bool = {false}) throws -> DeformingContactPolicy {
        try DeformingContactPolicy(maximumNodes:100,maximumCells:cells,maximumFaces:faces,maximumContacts:10,maximumIdentifierBytes:identifiers,
            minimumVolume:1e-12,minimumDoubleArea:1e-10,lengthTolerance:1e-9,barycentricInterior:1e-7,
            forceTolerance:1e-7,momentTolerance:1e-7,powerTolerance:1e-7,rotationTolerance:1e-10,isCancelled:{cancelled || cancellation()})
    }
    static func material() throws -> FlexibleMaterial { try FlexibleMaterial(identifier:EntityID(kind:.material,key:"solid"),source:SourceProvenance(source:"material",revision:1),
        law:PolynomialHyperelasticity(elasticity:IsotropicElasticity(bulkModulus:1000,shearModulus:400),nonlinearModulus:0,domain:StrainDomain(maximumStrainNorm:2,minimumVolumeRatio:0.1)),referenceDensity:1,massDampingRate:0) }
    static func mesh(points: [Vector3]=[.zero,.unitX,.unitY,.unitZ], cells: [[Int]]=[[0,1,2,3]]) throws -> ValidatedTetrahedralMesh {
        let m=try material(), source=try SourceProvenance(source:"identified solid",revision:1)
        let nodes=points.enumerated().map { FlexibleNode(identifier:UInt64(10+$0.offset),referencePosition:$0.element) }
        var elements: [TetrahedronCell]=[]
        for i in cells.indices { elements.append(try TetrahedronCell(identifier:UInt64(100+i),nodes:cells[i],material:m.identifier,source:source)) }
        let raw=try TetrahedralMesh(frame:EntityID(kind:.frame,key:"world"),revision:1,source:source,nodes:nodes,cells:elements,materials:[m])
        var work=try work(); let service:any TetrahedralMeshValidating=TetrahedralMeshValidator()
        return try service.validate(raw,admission:MeshAdmission(maximumNodes:100,maximumCells:100,maximumMaterials:2,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12),work:&work)
    }
    static func surface(_ mesh: ValidatedTetrahedralMesh) throws -> MaterialSurface {
        var work=try work(); let service:any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater()
        return try service.extract(mesh,body:ModelReference(id:EntityID(kind:.body,key:"flexible"),revision:1),policy:policy(),work:&work)
    }
    static func snapshot(_ surface: MaterialSurface, positions: [Vector3]?=nil, velocities: [Vector3]?=nil, revision: UInt64=1, time: Double=0,
                         previous: DeformingSurfaceSnapshot?=nil) throws -> DeformingSurfaceSnapshot {
        let state=NodalState(frame:surface.mesh.mesh.frame,meshRevision:surface.mesh.mesh.revision,nodeIdentifiers:surface.mesh.mesh.nodes.map { $0.identifier },
            positions:positions ?? surface.mesh.mesh.nodes.map { $0.referencePosition },velocities:velocities ?? surface.mesh.mesh.nodes.map { _ in .zero })
        var work=try work(); let service:any DeformingSurfaceUpdating=TetrahedralBoundaryUpdater()
        return try service.update(surface,state:state,geometryRevision:revision,time:time,previous:previous,policy:policy(),work:&work)
    }
    static func collisionWork() throws -> CollisionWork { CollisionWork(budget:try CollisionBudget(scalarStorage:1000,operations:100_000,iterations:0,records:10)) }
    static func collisionPolicy() throws -> CollisionQueryPolicy { try CollisionQueryPolicy(absoluteLengthTolerance:1e-10,relativeLengthTolerance:1e-10,referenceLength:1,maximumApproximationError:0) }
    static func plane() throws -> CollisionProxy {
        let source=try SourceProvenance(source:"analytic plane",revision:1)
        let repr=try GeometryRepresentation(kind:.collisionGeometry,assetKey:"plane",provenance:source,quality:.exact)
        return try CollisionProxy(colliderID:EntityID(kind:.collider,key:"plane"),bodyID:EntityID(kind:.body,key:"ground"),frameID:EntityID(kind:.frame,key:"world"),
            geometryRevision:1,frameRevision:1,shape:.halfSpace,margin:0,representations:BodyRepresentations(collisionGeometry:repr),expectedSourceRevision:1,
            resolution:.analytic,pose:.identity,filter:ColliderFilter(enabled:true,layerBits:1,maskBits:UInt64.max,isTrigger:false))
    }
    static func selfSnapshot(velocities: [Vector3]?=nil, rotation: UnitQuaternion = .identity) throws -> DeformingSurfaceSnapshot {
        let origin=try Vector3(0.2,0.2,0.01)
        var points: [Vector3]=[.zero,.unitX,.unitY,.unitZ,origin]
        points.append(try origin.adding(Vector3(0.1,0,0))); points.append(try origin.adding(Vector3(0,0.1,0))); points.append(try origin.adding(Vector3(0,0,0.1)))
        let m=try mesh(points:points,cells:[[0,1,2,3],[4,5,6,7]]), s=try surface(m)
        let actual=try points.map { try rotation.rotating($0) }
        let v=try (velocities ?? points.map { _ in .zero }).map { try rotation.rotating($0) }
        return try snapshot(s,positions:actual,velocities:v)
    }
    static func lawWork(operations: Int=1_000_000) throws -> ContactWork { ContactWork(budget:try ContactBudget(operations:operations,scalarStorage:1000,records:10)) }
    static func pair(friction: Bool=true) throws -> ContactLawPair {
        let f: ContactFrictionLaw = friction ? .elasticCoulomb(try ContactFrictionParameters(staticFirst:0.8,staticSecond:0.8,dynamicFirst:0.4,dynamicSecond:0.4,tangentialStiffness:2000,transitionSpeed:0.1)) : .none
        func material(_ key: String) throws -> ContactMaterial { try ContactMaterial(reference:ModelReference(id:EntityID(kind:.material,key:key),revision:1),youngModulus:1e6,poissonsRatio:0.25,
            linearStiffness:2000,normalDamping:0,huntCrossleyAlpha:0,friction:f,resistance:ContactResistanceParameters(rollingCoefficient:0,spinningCoefficient:0,angularRegularization:0.1),cohesion:.none) }
        var work=try lawWork(); let service:any ContactMaterialPairing=SeriesContactPairing()
        return try service.combine(first:material("first"),second:material("second"),selection:.linear(maximumPenetration:0.2,maximumNormalSpeed:100),lossPolicy:.compliantDampingOnly,resistanceRadius:1,override:nil,work:&work)
    }
    static func lawPolicy() throws -> ContactAcceptancePolicy { try ContactAcceptancePolicy(absoluteEnergyTolerance:1e-10,absolutePowerTolerance:1e-10,relativeTolerance:1e-11,referenceEnergy:1,referencePower:1,coneTolerance:1e-11) }
    static func selfWitness(_ snapshot: DeformingSurfaceSnapshot) throws -> SurfaceContactWitness {
        var work=try work(); let service:any SurfaceWitnessQuerying=SelectedSurfaceWitnessQueries()
        return try service.selfContact(snapshot,first:SurfaceFeatureID(cell:101,oppositeNode:1),vertex:0,second:SurfaceFeatureID(cell:100,oppositeNode:3),policy:policy(),work:&work)
    }
    static func selfMoving(rotation: UnitQuaternion = .identity) throws -> DeformingSurfaceSnapshot {
        var velocities=[Vector3](repeating:.zero,count:8); velocities[4] = .unitX
        return try selfSnapshot(velocities:velocities,rotation:rotation)
    }
    static func close(_ a: Double,_ b: Double, tolerance: Double=1e-8) -> Bool { abs(a-b) <= tolerance }
}
