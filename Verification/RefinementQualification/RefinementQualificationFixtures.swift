import SwiftMechanics

internal enum RefinementQualificationFixtures {
    typealias E=RefinementQualificationError
    enum Geometry { case single,sharedFace,disconnected,overlap,hanging,coincident,nonmanifold }
    enum Failure {
        case invalid,capacity,cancelled,source,revision,layout,frame,policy,assignment,collision,overflow
        case nonconforming,topology,physical,boundary,load,supplierQuality,storage(Int),operations(Int)
    }
    static func require(_ condition: Bool,_ label: String) throws(E) { guard condition else { throw .assertion(label) } }
    static func near(_ actual: Double,_ expected: Double,_ label: String) throws(E) {
        try require(actual.isFinite && expected.isFinite && abs(actual-expected)<=1e-9*max(1,max(abs(actual),abs(expected))),label)
    }
    static func near(_ a: Vector3,_ b: Vector3,_ label: String) throws(E) {
        try near(a.x,b.x,label+" x");try near(a.y,b.y,label+" y");try near(a.z,b.z,label+" z")
    }
    static func core<T>(_ body: () throws(CoreError) -> T) throws(E) -> T { do { return try body() } catch { throw .core(error) } }
    static func model<T>(_ body: () throws(ModelError) -> T) throws(E) -> T { do { return try body() } catch { throw .model(error) } }
    static func material<T>(_ body: () throws(MaterialError) -> T) throws(E) -> T { do { return try body() } catch { throw .material(error) } }
    static func flexible<T>(_ body: () throws(FlexibleError) -> T) throws(E) -> T { do { return try body() } catch { throw .flexible(error) } }
    static func numerical<T>(_ body: () throws(NumericalError) -> T) throws(E) -> T { do { return try body() } catch { throw .numerical(error) } }
    static func refinement<T>(_ body: () throws(RefinementError) -> T) throws(E) -> T { do { return try body() } catch { throw .producer(error) } }
    static func vector(_ x: Double,_ y: Double,_ z: Double) throws(E) -> Vector3 { try core { () throws(CoreError) in try Vector3(x,y,z) } }
    static func subtract(_ a: Vector3,_ b: Vector3) throws(E) -> Vector3 { try vector(a.x-b.x,a.y-b.y,a.z-b.z) }
    static func midpoint(_ a: Vector3,_ b: Vector3) throws(E) -> Vector3 { try vector((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2) }
    static func add(_ a: Vector3,_ b: Vector3) throws(E) -> Vector3 { try vector(a.x+b.x,a.y+b.y,a.z+b.z) }
    static func scale(_ a: Vector3,_ s: Double) throws(E) -> Vector3 { try vector(a.x*s,a.y*s,a.z*s) }
    static func dot(_ a: Vector3,_ b: Vector3) -> Double { a.x*b.x+a.y*b.y+a.z*b.z }
    static func cross(_ a: Vector3,_ b: Vector3) throws(E) -> Vector3 { try vector(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x) }
    static func volume(_ p: [Vector3],_ nodes: [Int]) throws(E) -> Double {
        let a=try subtract(p[nodes[1]],p[nodes[0]]),b=try subtract(p[nodes[2]],p[nodes[0]]),c=try subtract(p[nodes[3]],p[nodes[0]])
        return dot(a,try cross(b,c))/6
    }
    static func area(_ p: [Vector3],_ nodes: [Int]) throws(E) -> Vector3 {
        try cross(subtract(p[nodes[1]],p[nodes[0]]),subtract(p[nodes[2]],p[nodes[0]]))
    }
    static func identity(_ kind: EntityKind,_ name: String) throws(E) -> EntityID { try model { () throws(ModelError) in try EntityID(kind:kind,key:name) } }
    static func provenance(_ name: String,_ revision: UInt64) throws(E) -> SourceProvenance { try model { () throws(ModelError) in try SourceProvenance(source:name,revision:revision) } }
    static func work(storage: Int = 200_000,operations: Int = 5_000_000) throws(E) -> NumericalWork {
        let budget=try numerical { () throws(NumericalError) in try NumericalBudget(scalarStorage:storage,arithmeticOperations:operations,iterations:0) }
        return NumericalWork(budget:budget)
    }
    static func policy(nodes: Int = 64,cells: Int = 32,edges: Int = 32,faces: Int = 128,bytes: Int = 256,scalars: Int = 200_000,
                       conformity: Double = 1e-10,barycentric: Double = 1e-10,minimumCurrentVolume: Double = 1e-12,
                       cancelled: @escaping @Sendable () -> Bool = {false}) throws(E) -> RefinementPolicy {
        try refinement { () throws(RefinementError) in try RefinementPolicy(maximumNodes:nodes,maximumCells:cells,maximumMaterials:4,maximumEdges:edges,maximumFaces:faces,
            maximumIdentifierBytes:bytes,maximumScalars:scalars,conformityTolerance:conformity,barycentricTolerance:barycentric,volumeTolerance:1e-10,areaTolerance:1e-10,
            minimumCurrentVolume:minimumCurrentVolume,forceTolerance:1e-10,momentTolerance:1e-10,powerTolerance:1e-10,isCancelled:cancelled) }
    }
    static func admission(minimum: Double = 1e-12) throws(E) -> MeshAdmission {
        try flexible { () throws(FlexibleError) in try MeshAdmission(maximumNodes:64,maximumCells:32,maximumMaterials:4,minimumReferenceVolume:minimum,inverseRelativeTolerance:1e-12) }
    }
    static func position(_ x: Vector3,rigid: Bool = false) throws(E) -> Vector3 {
        if rigid { return try vector(2-x.y,-1+x.x,0.5+x.z) }
        return try vector(2+x.x+x.y/4,-1+2*x.y,0.5+x.z/2)
    }
    static func velocity(_ x: Vector3,rigid: Bool = false) throws(E) -> Vector3 {
        if rigid { return try vector(0.5-x.y,-1+x.x,2) }
        return try vector(0.5+x.x/10+x.y/5,-1-3*x.y/10,2+2*x.z/5)
    }
    static func source(_ geometry: Geometry = .single,apex: Vector3? = nil,rigid: Bool = false) throws(E) -> Tet4RefinementSource {
        var points: [Vector3]=[.zero,.unitX,.unitY,apex ?? .unitZ],connectivity=[[0,1,2,3]]
        switch geometry {
        case .single:break
        case .sharedFace:points.append(try vector(0,0,-1));connectivity.append([0,2,1,4])
        case .nonmanifold:points += try [vector(0,0,-1),vector(0,0,-2)];connectivity += [[0,2,1,4],[0,2,1,5]]
        case .disconnected:points += try [vector(3,0,0),vector(4,0,0),vector(3,1,0),vector(3,0,1)];connectivity.append([4,5,6,7])
        case .overlap:points += try [vector(0.1,0.1,0.1),vector(1.1,0.1,0.1),vector(0.1,1.1,0.1),vector(0.1,0.1,1.1)];connectivity.append([4,5,6,7])
        case .coincident:points += [.zero,.unitX,.unitY,.unitZ];connectivity.append([4,5,6,7])
        case .hanging:points += try [vector(0.25,0.25,0),vector(0.75,0.25,0),vector(0.25,0.75,0),vector(0.25,0.25,-1)];connectivity.append([4,6,5,7])
        }
        let frame=try identity(.frame,"world"),origin=try provenance("qualified-refinement-mesh",7)
        var materials: [FlexibleMaterial]=[],cells: [TetrahedronCell]=[],nodes: [FlexibleNode]=[],positions: [Vector3]=[],velocities: [Vector3]=[],ids: [UInt64]=[]
        for (i,indices) in connectivity.enumerated() {
            let id=try identity(.material,"refinement-material-"+String(i)),source=try provenance("material-source-"+String(i),3)
            let elasticity=try material { () throws(MaterialError) in try IsotropicElasticity(bulkModulus:12,shearModulus:3) }
            let domain=try material { () throws(MaterialError) in try StrainDomain(maximumStrainNorm:0.5,minimumVolumeRatio:0.2) }
            let law=try material { () throws(MaterialError) in try PolynomialHyperelasticity(elasticity:elasticity,nonlinearModulus:0,domain:domain) }
            materials.append(try flexible { () throws(FlexibleError) in try FlexibleMaterial(identifier:id,source:source,law:law,referenceDensity:6,massDampingRate:0) })
            let cellSource=try provenance("cell-source-"+String(i),2)
            cells.append(try flexible { () throws(FlexibleError) in try TetrahedronCell(identifier:UInt64(50+i*10),nodes:indices,material:id,source:cellSource) })
        }
        for (i,p) in points.enumerated() {
            let id=UInt64(10+10*i);ids.append(id)
            nodes.append(FlexibleNode(identifier:id,referencePosition:p,boundaryGroup:UInt64(100+i)))
            positions.append(try position(p,rigid:rigid));velocities.append(try velocity(p,rigid:rigid))
        }
        let raw=try flexible { () throws(FlexibleError) in try TetrahedralMesh(frame:frame,revision:7,source:origin,nodes:nodes,cells:cells,materials:materials) }
        let validator: any TetrahedralMeshValidating=TetrahedralMeshValidator(),admission=try Self.admission()
        var work=try Self.work()
        let validated=try flexible { () throws(FlexibleError) in try validator.validate(raw,admission:admission,work:&work) }
        return try refinement { () throws(RefinementError) in try Tet4RefinementSource(mesh:validated,state:NodalState(frame:frame,meshRevision:7,nodeIdentifiers:ids,positions:positions,velocities:velocities),timeSeconds:0.5,geometryRevision:4) }
    }
    static func source(_ original: Tet4RefinementSource,state: NodalState) throws(E) -> Tet4RefinementSource {
        try refinement { () throws(RefinementError) in try Tet4RefinementSource(mesh:original.mesh,state:state,timeSeconds:original.timeSeconds,geometryRevision:original.geometryRevision) }
    }
    static func changed(_ s: NodalState,frame: EntityID? = nil,revision: UInt64? = nil,ids: [UInt64]? = nil,positions: [Vector3]? = nil,velocities: [Vector3]? = nil) -> NodalState {
        NodalState(frame:frame ?? s.frame,meshRevision:revision ?? s.meshRevision,nodeIdentifiers:ids ?? s.nodeIdentifiers,positions:positions ?? s.positions,velocities:velocities ?? s.velocities)
    }
    static func layout(_ source: Tet4RefinementSource,policy supplied: RefinementPolicy? = nil) throws(E) -> Tet4RefinementLayout {
        let p: RefinementPolicy
        if let supplied { p=supplied } else { p=try policy() }
        let producer: any Tet4RedRefining=ConformingTet4RedRefiner();var work=try Self.work()
        return try refinement { () throws(RefinementError) in try producer.layout(source:source,policy:p,work:&work) }
    }
    static func groups(_ layout: Tet4RefinementLayout) throws(E) -> RefinementBoundaryAssignments {
        var midpoint: [UInt64?]=[],face: [UInt64?]=[]
        for i in layout.edges.indices { midpoint.append(i%2==0 ? UInt64(700+i) : nil) }
        for i in layout.boundaryFaces.indices { face.append(i%2==0 ? UInt64(900+i) : nil) }
        return try refinement { () throws(RefinementError) in try RefinementBoundaryAssignments(layout:layout,owner:"caller-boundary-decisions",midpointGroups:midpoint,originalFaceGroups:face) }
    }
    static func forces(_ source: Tet4RefinementSource) throws(E) -> [Vector3] {
        var result=try [vector(1,2,3),vector(-2,1,0),vector(0,-1,2),vector(3,0,-2)]
        while result.count<source.mesh.mesh.nodes.count { result.append(.zero) }
        return result
    }
    static func loads(_ source: Tet4RefinementSource) throws(E) -> ConcentratedRefinementLoads {
        let forces=try Self.forces(source)
        return try refinement { () throws(RefinementError) in try ConcentratedRefinementLoads(source:source,forces:forces) }
    }
    static func refine(_ layout: Tet4RefinementLayout,diagonal: CentralOctahedronDiagonalPolicy = .lexicographicOppositeEdges,
                       policy supplied: RefinementPolicy? = nil) throws(E) -> Tet4RefinementResult {
        let p: RefinementPolicy
        if let supplied { p=supplied } else { p=try policy() }
        let producer: any Tet4RedRefining=ConformingTet4RedRefiner(),groups=try Self.groups(layout),loads=try Self.loads(layout.source),admission=try Self.admission()
        var work=try Self.work()
        return try refinement { () throws(RefinementError) in try producer.refine(layout,meshRevision:8,geometryRevision:5,identifiers:RefinementIdentifierAllocation(firstMidpointNode:1000,firstChildCell:2000),diagonal:diagonal,boundary:.explicitGroups(groups),loads:loads,loadPolicy:.retainConcentratedOriginalNodes,policy:p,admission:admission,work:&work) }
    }
    static func expect(_ wanted: Failure,_ body: () throws(RefinementError) -> Void) throws(E) {
        do { try body() } catch {
            let matches: Bool
            switch (wanted,error) {
            case (.invalid,.invalidInput),(.capacity,.capacityExceeded),(.cancelled,.cancelled),(.source,.staleSource),(.revision,.staleRevision),(.layout,.staleLayout),
                 (.frame,.frameMismatch),(.policy,.topologyPolicyMismatch),(.assignment,.invalidAssignment),(.collision,.identifierCollision),(.overflow,.identifierOverflow),
                 (.nonconforming,.nonconformingMesh),(.topology,.invalidTopology),(.physical,.physicalResidual),(.boundary,.unsupportedBoundaryMapping),(.load,.unsupportedLoadMapping),
                 (.supplierQuality,.flexible(.invalidReferenceCell(element:2000))):matches=true
            case (.storage(let expected),.numerical(.resourceLimit(resource:.scalarStorage,limit:let actual))),
                 (.operations(let expected),.numerical(.resourceLimit(resource:.arithmeticOperations,limit:let actual))):matches=expected==actual
            default:matches=false
            }
            guard matches else { throw .producer(error) };return
        }
        throw .assertion("Expected exact typed refinement refusal")
    }
}
