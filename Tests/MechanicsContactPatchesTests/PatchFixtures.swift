import MechanicsCore
import MechanicsModel
import MechanicsMaterials
import MechanicsNumerics
import MechanicsFlexible
import MechanicsContactPatches
internal enum PatchFixtures {
    static func work(storage: Int = 100_000,operations: Int = 1_000_000) throws -> NumericalWork { NumericalWork(budget:try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0)) }
    static func admission() throws -> MeshAdmission { try MeshAdmission(maximumNodes:20,maximumCells:20,maximumMaterials:4,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12) }
    static func mesh() throws -> ValidatedTetrahedralMesh {
        let material=try FlexibleMaterial(identifier:EntityID(kind:.material,key:"solid"),source:SourceProvenance(source:"material",revision:1),
            law:PolynomialHyperelasticity(elasticity:IsotropicElasticity(bulkModulus:1000,shearModulus:400),nonlinearModulus:0,domain:StrainDomain(maximumStrainNorm:2,minimumVolumeRatio:0.2)),referenceDensity:1,massDampingRate:0)
        let raw=try TetrahedralMesh(frame:EntityID(kind:.frame,key:"world"),revision:1,source:SourceProvenance(source:"tetra source",revision:1),
            nodes:[FlexibleNode(identifier:10,referencePosition:.zero),FlexibleNode(identifier:11,referencePosition:.unitX),FlexibleNode(identifier:12,referencePosition:.unitY),FlexibleNode(identifier:13,referencePosition:.unitZ)],
            cells:[TetrahedronCell(identifier:50,nodes:[0,1,2,3],material:material.identifier,source:SourceProvenance(source:"cell",revision:1))],materials:[material])
        var work=try Self.work(); return try TetrahedralMeshValidator().validate(raw,admission:admission(),work:&work)
    }
    static func body(_ mesh: ValidatedTetrahedralMesh,transform: RigidTransform = .identity,missing: Bool = false,pressureRevision: UInt64 = 3,inverted: Bool = false,constant: Bool = false) throws -> PressureBody {
        var points: [Vector3]=[], velocities: [Vector3]=[], ids: [UInt64]=[], pressure: [Double]=[]
        for node in mesh.mesh.nodes {
            let x=node.referencePosition; var point=try transform.transforming(point:x)
            if inverted { point=try Vector3(-x.x,x.y,x.z) }
            points.append(point); velocities.append(try transform.transforming(direction:Vector3(0,0,1+x.x+2*x.y+3*x.z)))
            ids.append(node.identifier); pressure.append(constant ? 5 : 2+3*x.x+4*x.y+5*x.z)
        }
        let state=NodalState(frame:mesh.mesh.frame,meshRevision:mesh.mesh.revision,nodeIdentifiers:ids,positions:points,velocities:velocities)
        let field=NodalPressureField(frame:mesh.mesh.frame,meshRevision:mesh.mesh.revision,revision:pressureRevision,nodeIdentifiers:ids,materialIdentifiers:mesh.mesh.materials.map(\.identifier),pressurePascals:pressure,source:mesh.mesh.source)
        return PressureBody(body:ModelReference(id:try EntityID(kind:.body,key:"soft"),revision:9),mesh:mesh,state:state,field:missing ? nil : field)
    }
    static func plane(_ frame: EntityID,transform: RigidTransform = .identity,normal: Vector3 = .unitZ,point: Vector3? = nil,revision: UInt64 = 4) throws -> RigidPressurePlane {
        RigidPressurePlane(body:ModelReference(id:try EntityID(kind:.body,key:"rigid"),revision:9),frame:ModelReference(id:frame,revision:9),revision:revision,
            point:try transform.transforming(point:point ?? Vector3(0,0,0.2)),normal:try transform.transforming(direction:normal),
            velocityAboutPoint:SpatialMotion(angular:try transform.transforming(direction:.unitX),linear:try transform.transforming(direction:Vector3(0,0,0.5))))
    }
    static func policy(meshRevision: UInt64 = 1,maximumTriangles: Int = 40,cancelled: @escaping @Sendable () -> Bool = {false}) throws -> PatchPolicy {
        try PatchPolicy(maximumNodes:20,maximumCells:20,maximumTriangles:maximumTriangles,expectedModelRevision:9,expectedMeshRevision:meshRevision,expectedPressureRevision:3,expectedPlaneRevision:4,
            maximumPressure:100,minimumDeterminant:1e-10,minimumTriangleArea:1e-12,planeDistanceTolerance:1e-10,normalTolerance:1e-10,forceScale:1,momentScale:1,powerScale:1,residualTolerance:1e-8,isCancelled:cancelled)
    }
    static func solve(_ body: PressureBody,_ plane: RigidPressurePlane,origin: Vector3 = .zero) throws -> PressurePatchResult {
        var work=try Self.work(), workspace=PatchWorkspace(); let service: any PressurePatchIntegrating=TetrahedralPressurePatchIntegrator()
        return try service.integrate(body,against:.rigidPlane(plane),origin:origin,policy:policy(meshRevision:body.mesh.mesh.revision),workspace:&workspace,work:&work)
    }
    static func close(_ a: Double,_ b: Double) -> Bool { abs(a-b) <= 1e-8*max(1,max(abs(a),abs(b))) }
    static func close(_ a: Vector3,_ b: Vector3) -> Bool { close(a.x,b.x) && close(a.y,b.y) && close(a.z,b.z) }
}
