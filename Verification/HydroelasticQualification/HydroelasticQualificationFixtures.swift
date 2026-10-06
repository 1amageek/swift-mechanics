import SwiftMechanics

internal enum HydroelasticQualificationFixtures {
    typealias E = HydroelasticQualificationError

    enum Failure {
        case stale, frame, sample, material, layout, missingField, missingCell, inverted
        case boundary, ambiguous, capacity, cancelled, invalid, wholeMesh, surface, evolution
        case storage(Int), operations(Int)
    }

    static func require(_ condition: Bool, _ label: String) throws(E) {
        guard condition else { throw .assertion(label) }
    }
    static func near(_ actual: Double, _ expected: Double, _ label: String) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected) <= 1e-9*max(1,max(abs(actual),abs(expected))), label)
    }
    static func near(_ actual: Vector3, _ expected: Vector3, _ label: String) throws(E) {
        try near(actual.x,expected.x,label+" x"); try near(actual.y,expected.y,label+" y"); try near(actual.z,expected.z,label+" z")
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T {
        do { return try body() } catch { throw .core(error) }
    }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T {
        do { return try body() } catch { throw .model(error) }
    }
    static func flexible<T>(_ body: () throws(FlexibleError) -> T) throws(E) -> T {
        do { return try body() } catch { throw .flexible(error) }
    }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(E) -> T {
        do { return try body() } catch { throw .material(error) }
    }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(E) -> T {
        do { return try body() } catch { throw .numerical(error) }
    }
    static func producer<T>(_ body: () throws(HydroelasticError) -> T) throws(E) -> T {
        do { return try body() } catch { throw .producer(error) }
    }
    static func vector(_ x: Double,_ y: Double,_ z: Double) throws(E) -> Vector3 {
        try core { () throws(CoreError) in try Vector3(x,y,z) }
    }
    static func source(_ name: String,_ revision: UInt64 = 1) throws(E) -> SourceProvenance {
        try model { () throws(ModelError) in try SourceProvenance(source:name,revision:revision) }
    }
    static func identity(_ kind: EntityKind,_ name: String) throws(E) -> EntityID {
        try model { () throws(ModelError) in try EntityID(kind:kind,key:name) }
    }
    static func work(storage: Int = 100_000,operations: Int = 1_000_000) throws(E) -> NumericalWork {
        let budget=try numerical { () throws(NumericalError) in try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0) }
        return NumericalWork(budget:budget)
    }
    static func policy(nodes: Int = 20,metadata: Int = 256,vertices: Int = 8,triangles: Int = 6,
                       pressure: Double = 100,residual: Double = 1e-8,
                       cancelled: @escaping @Sendable () -> Bool = { false }) throws(E) -> HydroelasticPolicy {
        try producer { () throws(HydroelasticError) in
            try HydroelasticPolicy(maximumNodes:nodes,maximumCells:20,maximumMaterials:4,maximumMetadataBytes:metadata,
                maximumVertices:vertices,maximumTriangles:triangles,maximumPressure:pressure,minimumVolumeRatio:1e-10,
                inverseRelativeTolerance:1e-12,minimumTriangleArea:1e-12,distanceTolerance:1e-9,barycentricTolerance:1e-10,
                normalTolerance:1e-10,pressureTolerance:1e-9,gradientTolerance:1e-12,forceScale:1,momentScale:1,powerScale:1,
                residualTolerance:residual,isCancelled:cancelled)
        }
    }
    static func standardVertices() -> [Vector3] { [.zero,.unitX,.unitY,.unitZ] }
    static func shiftedVertices(_ dx: Double,_ dy: Double,_ dz: Double) throws(E) -> [Vector3] {
        try [vector(dx,dy,dz),vector(dx+1,dy,dz),vector(dx,dy+1,dz),vector(dx,dy,dz+1)]
    }
    static func cell(_ name: String,vertices: [Vector3] = standardVertices(),current: [Vector3]? = nil,
                     pressure: (Vector3) -> Double = { 2+3*$0.x+4*$0.y+5*$0.z },
                     velocity: (Vector3) -> Double = { 1+$0.x+2*$0.y+3*$0.z }) throws(E) -> HydroelasticCellSelection {
        let materialID=try identity(.material,name+"-material"), materialSource=try source(name+"-material"), frame=try identity(.frame,"world")
        let elasticity=try material { () throws(MaterialError) in try IsotropicElasticity(bulkModulus:1000,shearModulus:400) }
        let domain=try material { () throws(MaterialError) in try StrainDomain(maximumStrainNorm:2,minimumVolumeRatio:0.2) }
        let law=try material { () throws(MaterialError) in try PolynomialHyperelasticity(elasticity:elasticity,nonlinearModulus:0,domain:domain) }
        let mat=try flexible { () throws(FlexibleError) in try FlexibleMaterial(identifier:materialID,source:materialSource,law:law,referenceDensity:1,massDampingRate:0) }
        let cellSource=try source(name+"-cell"), meshSource=try source(name+"-mesh")
        let element=try flexible { () throws(FlexibleError) in try TetrahedronCell(identifier:50,nodes:[0,1,2,3],material:materialID,source:cellSource) }
        var nodes: [FlexibleNode]=[]
        for i in vertices.indices { nodes.append(FlexibleNode(identifier:UInt64(10+i),referencePosition:vertices[i])) }
        let raw=try flexible { () throws(FlexibleError) in try TetrahedralMesh(frame:frame,revision:1,source:meshSource,nodes:nodes,cells:[element],materials:[mat]) }
        let admission=try flexible { () throws(FlexibleError) in try MeshAdmission(maximumNodes:20,maximumCells:20,maximumMaterials:4,minimumReferenceVolume:1e-12,inverseRelativeTolerance:1e-12) }
        var meshWork=try work()
        let validator: any TetrahedralMeshValidating=TetrahedralMeshValidator()
        let mesh=try flexible { () throws(FlexibleError) in try validator.validate(raw,admission:admission,work:&meshWork) }
        let positions=current ?? vertices
        var velocities: [Vector3]=[], pressures: [Double]=[]
        for x in positions { velocities.append(try vector(0,0,velocity(x))); pressures.append(pressure(x)) }
        let ids: [UInt64]=[10,11,12,13]
        let state=NodalState(frame:frame,meshRevision:1,nodeIdentifiers:ids,positions:positions,velocities:velocities)
        let field=NodalPressureField(frame:frame,meshRevision:1,revision:3,nodeIdentifiers:ids,materialIdentifiers:[materialID],pressurePascals:pressures,source:meshSource)
        let bodyID=try identity(.body,name)
        let body=PressureBody(body:ModelReference(id:bodyID,revision:9),mesh:mesh,state:state,field:field)
        let calibrationSource=try source(name+"-pressure-calibration",7)
        let calibration=try producer { () throws(HydroelasticError) in
            try HydroelasticCalibration(source:calibrationSource,material:materialID,materialSource:materialSource,
                declaredPressureApproximationPascals:0.25,declaredGeometryApproximationMeters:0.0001)
        }
        let sample=try source("physical-sample",9)
        return try producer { () throws(HydroelasticError) in
            try HydroelasticCellSelection(representation:body,cellIdentifier:50,expectedModelRevision:9,expectedMeshRevision:1,
                expectedPressureRevision:3,expectedMeshSource:meshSource,expectedCellSource:cellSource,calibration:calibration,
                expectedCalibrationSource:calibrationSource,sample:sample,sampleTimeSeconds:0.5)
        }
    }
    static func plane(_ first: HydroelasticCellSelection,point: Vector3? = nil,normal: Vector3 = .unitZ,
                      linear: Vector3? = nil,angular: Vector3 = .unitX) throws(E) -> HydroelasticPlaneSelection {
        let p: Vector3, v: Vector3
        if let point { p=point } else { p=try vector(0.1,-0.3,0.2) }
        if let linear { v=linear } else { v=try vector(0.2,0.4,0.5) }
        let body=try identity(.body,"rigid"), source=try source("plane-geometry",4)
        let representation=RigidPressurePlane(body:ModelReference(id:body,revision:9),frame:ModelReference(id:first.representation.mesh.mesh.frame,revision:9),revision:4,
            point:p,normal:normal,velocityAboutPoint:SpatialMotion(angular:angular,linear:v))
        return try producer { () throws(HydroelasticError) in
            try HydroelasticPlaneSelection(representation:representation,expectedModelRevision:9,expectedPlaneRevision:4,
                geometrySource:source,expectedGeometrySource:source,sample:first.sample,sampleTimeSeconds:first.sampleTimeSeconds)
        }
    }
    static func selection(_ input: HydroelasticCellSelection,body: PressureBody? = nil,cell: UInt64? = nil,model: UInt64? = nil,
                          meshRevision: UInt64? = nil,pressureRevision: UInt64? = nil,meshSource: SourceProvenance? = nil,
                          cellSource: SourceProvenance? = nil,calibration: HydroelasticCalibration? = nil,
                          calibrationSource: SourceProvenance? = nil,sample: SourceProvenance? = nil,time: Double? = nil) throws(E) -> HydroelasticCellSelection {
        try producer { () throws(HydroelasticError) in
            try HydroelasticCellSelection(representation:body ?? input.representation,cellIdentifier:cell ?? input.cellIdentifier,
                expectedModelRevision:model ?? input.expectedModelRevision,expectedMeshRevision:meshRevision ?? input.expectedMeshRevision,
                expectedPressureRevision:pressureRevision ?? input.expectedPressureRevision,expectedMeshSource:meshSource ?? input.expectedMeshSource,
                expectedCellSource:cellSource ?? input.expectedCellSource,calibration:calibration ?? input.calibration,
                expectedCalibrationSource:calibrationSource ?? input.expectedCalibrationSource,sample:sample ?? input.sample,sampleTimeSeconds:time ?? input.sampleTimeSeconds)
        }
    }
    static func body(_ input: HydroelasticCellSelection,state: NodalState? = nil,field: NodalPressureField? = nil,missing: Bool = false) -> PressureBody {
        let body=input.representation
        return PressureBody(body:body.body,mesh:body.mesh,state:state ?? body.state,field:missing ? nil : (field ?? body.field))
    }
    static func field(_ input: HydroelasticCellSelection,frame: EntityID? = nil,revision: UInt64? = nil,meshRevision: UInt64? = nil,
                      ids: [UInt64]? = nil,materials: [EntityID]? = nil,pressure: [Double]? = nil,source: SourceProvenance? = nil) throws(E) -> NodalPressureField {
        guard let original=input.representation.field else { throw .assertion("Fixture field missing") }
        return NodalPressureField(frame:frame ?? original.frame,meshRevision:meshRevision ?? original.meshRevision,revision:revision ?? original.revision,
            nodeIdentifiers:ids ?? original.nodeIdentifiers,materialIdentifiers:materials ?? original.materialIdentifiers,
            pressurePascals:pressure ?? original.pressurePascals,source:source ?? original.source)
    }
    static func solve(_ first: HydroelasticCellSelection,_ second: HydroelasticPartner,origin: Vector3 = .zero,
                      policy supplied: HydroelasticPolicy? = nil) throws(E) -> HydroelasticPatch {
        let policy: HydroelasticPolicy
        if let supplied { policy=supplied } else { policy=try Self.policy() }
        var work=try Self.work()
        let service: any HydroelasticPatchConstructing=ReferenceHydroelasticPatchConstructor()
        return try producer { () throws(HydroelasticError) in try service.construct(first,against:second,origin:origin,policy:policy,work:&work) }
    }
    static func expect(_ failure: Failure,_ body: () throws(HydroelasticError) -> Void) throws(E) {
        do { try body() } catch {
            let matches: Bool
            switch (failure,error) {
            case (.stale,.staleRepresentation),(.frame,.frameMismatch),(.sample,.sampleMismatch),(.material,.incompatibleMaterial),
                 (.layout,.invalidLayout),(.missingField,.missingPressureField),(.missingCell,.missingCell(999)),(.inverted,.invertedCell(50)),
                 (.boundary,.boundaryDegeneracy),(.ambiguous,.ambiguousPressureVolume),(.capacity,.capacityExceeded),(.cancelled,.cancelled),
                 (.invalid,.invalidInput),(.wholeMesh,.unsupportedWholeMesh),(.surface,.unsupportedSurface),(.evolution,.unsupportedEvolution): matches=true
            case (.storage(let limit),.numerical(.resourceLimit(resource:.scalarStorage,limit:let actual))),
                 (.operations(let limit),.numerical(.resourceLimit(resource:.arithmeticOperations,limit:let actual))): matches=limit == actual
            default: matches=false
            }
            guard matches else { throw .producer(error) }
            return
        }
        throw .assertion("Expected exact typed refusal")
    }
    static func rotate(_ v: Vector3) throws(E) -> Vector3 { try vector(v.z,v.y,-v.x) }
    static func move(_ v: Vector3) throws(E) -> Vector3 { try vector(v.z+2,v.y-1,-v.x+0.5) }
    static func dot(_ a: Vector3,_ b: Vector3) -> Double { a.x*b.x+a.y*b.y+a.z*b.z }
    static func cross(_ a: Vector3,_ b: Vector3) throws(E) -> Vector3 { try vector(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    static func subtract(_ a: Vector3,_ b: Vector3) throws(E) -> Vector3 { try vector(a.x-b.x,a.y-b.y,a.z-b.z) }
    static func sum(_ values: [Vector3]) throws(E) -> Vector3 {
        var x=0.0,y=0.0,z=0.0
        for value in values { x+=value.x; y+=value.y; z+=value.z }
        return try vector(x,y,z)
    }
    static func polygon(_ patch: HydroelasticPatch,_ expected: [Vector3]) throws(E) {
        var vertices: [Vector3]=[]
        for triangle in patch.triangles {
            for point in [triangle.first,triangle.second,triangle.third] {
                if !vertices.contains(where: { abs($0.x-point.x)<1e-9 && abs($0.y-point.y)<1e-9 && abs($0.z-point.z)<1e-9 }) { vertices.append(point) }
            }
        }
        try require(vertices.count == expected.count,"Original polygon vertex count")
        for point in expected {
            try require(vertices.contains(where: { abs($0.x-point.x)<1e-9 && abs($0.y-point.y)<1e-9 && abs($0.z-point.z)<1e-9 }),"Original analytic polygon vertex")
        }
    }
    static func nodal(_ loads: [Vector3],_ state: NodalState,origin: Vector3,wrench: SpatialWrench,power: Double) throws(E) {
        try require(loads.count == state.positions.count && loads.count == state.velocities.count,"Nodal layout retained")
        var moments: [Vector3]=[], nodalPower=0.0
        for i in loads.indices { moments.append(try cross(subtract(state.positions[i],origin),loads[i])); nodalPower+=dot(loads[i],state.velocities[i]) }
        try near(sum(loads),wrench.force,"Nodal resultant"); try near(sum(moments),wrench.torque,"Nodal world moment"); try near(nodalPower,power,"Nodal original physical power")
    }
    static func residuals(_ result: HydroelasticPatch) throws(E) {
        try require(result.originalForceResidual <= 1e-8 && result.originalMomentResidual <= 1e-8 && result.originalPowerResidual <= 1e-8,"Original physical residual acceptance")
        try require(result.originalGeometryResidual <= 1 && result.originalPressureDifferencePascals <= 1e-9,"Original geometry/pressure residual acceptance")
        try require(result.work.operations > 0 && result.work.peakScalarStorage > 0,"Actual constitutive-independent query work")
    }
}
